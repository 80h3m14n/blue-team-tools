--[[
wireshark_stats.lua
Reusable Wireshark Lua plugin that provides:
1. Global packet counter
2. Protocol counters (frame.protocols)
3. Field extraction via Field.new()
4. Source / destination endpoint counters
5. DNS statistics (query types, response codes, top names)
6. HTTP metadata (methods, hosts, status codes, URIs)
7. TLS metadata (versions, SNI, ALPN, cipher suites)
8. TCP stream / conversation tracking
9. Top-N sorting for all major tables
10. Clean textual final report
11. Optional CSV export
12. Tools menu entry + console command

Installation (Linux / macOS / Windows):
Copy this file into the Wireshark plugins directory:
~/.local/lib/wireshark/plugins/   (Linux)
%APPDATA%\Wireshark\plugins\     (Windows)
~/Library/Application Support/Wireshark/plugins/  (macOS)
or any path listed under Help → About Wireshark → Folders → Personal Plugins.

Usage:
- Tools → Statistics → Advanced Stats Report
- or from the Lua console:  advanced_stats_report()
- Optional preference:  advanced_stats.top_n  (default 20)
- Optional preference:  advanced_stats.csv_path  (empty = no CSV)

Tested against Wireshark 4.6.8 Lua API.
--]]

local plugin_info = {
    version     = "1.2.2",
    author      = "Grok",
    description = "Advanced multi-protocol statistics + CSV + Tools menu"
}
set_plugin_info(plugin_info)

--------------------------------------------------------------------
-- Dummy protocol for preferences
--------------------------------------------------------------------
local p_stats = Proto("advanced_stats", "Advanced Stats")

p_stats.prefs.top_n       = Pref.uint  ("Top N items",             20,   "Number of entries shown in each Top-N table")
p_stats.prefs.csv_path    = Pref.string("CSV output path",         "",   "Absolute path for CSV report (empty = disabled)")
p_stats.prefs.enable_dns  = Pref.bool  ("Enable DNS stats",        true, "")
p_stats.prefs.enable_http = Pref.bool  ("Enable HTTP stats",       true, "")
p_stats.prefs.enable_tls  = Pref.bool  ("Enable TLS stats",        true, "")
p_stats.prefs.enable_tcp  = Pref.bool  ("Enable TCP stream stats", true, "")

--------------------------------------------------------------------
-- Safe Field.new wrapper
--------------------------------------------------------------------
local function safe_field(name)
local ok, f = pcall(Field.new, name)
if ok then
    return f
    else
        -- Uncomment the next line if you want to see which fields are missing
        -- print("[advanced_stats] Field not available: " .. name)
        return nil
        end
        end

        --------------------------------------------------------------------
        -- Field extractors (all created safely)
        --------------------------------------------------------------------
        local f_frame_protocols = safe_field("frame.protocols")
        local f_ip_src          = safe_field("ip.src")
        local f_ip_dst          = safe_field("ip.dst")
        local f_ipv6_src        = safe_field("ipv6.src")
        local f_ipv6_dst        = safe_field("ipv6.dst")
        local f_eth_src         = safe_field("eth.src")
        local f_eth_dst         = safe_field("eth.dst")

        -- DNS
        local f_dns_qry_name       = safe_field("dns.qry.name")
        local f_dns_qry_type       = safe_field("dns.qry.type")
        local f_dns_flags_rcode    = safe_field("dns.flags.rcode")
        local f_dns_flags_response = safe_field("dns.flags.response")

        -- HTTP
        local f_http_request_method = safe_field("http.request.method")
        local f_http_host           = safe_field("http.host")
        local f_http_request_uri    = safe_field("http.request.uri")
        local f_http_response_code  = safe_field("http.response.code")
        local f_http_user_agent     = safe_field("http.user_agent")

        -- TLS / SSL – try several possible names
        local f_tls_handshake_version = safe_field("tls.handshake.version")
        or safe_field("ssl.handshake.version")
        local f_tls_sni  = safe_field("tls.handshake.extensions_server_name")
        or safe_field("tls.handshake.extensions.server_name")
        or safe_field("ssl.handshake.extensions_server_name")
        local f_tls_alpn = safe_field("tls.handshake.extensions_alpn_str")
        or safe_field("tls.handshake.extensions.alpn_str")
        or safe_field("ssl.handshake.extensions_alpn_str")
        local f_tls_cipher = safe_field("tls.handshake.ciphersuite")
        or safe_field("ssl.handshake.ciphersuite")

        -- TCP
        local f_tcp_stream  = safe_field("tcp.stream")
        local f_tcp_srcport = safe_field("tcp.srcport")
        local f_tcp_dstport = safe_field("tcp.dstport")
        local f_tcp_len     = safe_field("tcp.len")

        --------------------------------------------------------------------
        -- Helper that safely extracts a field value
        --------------------------------------------------------------------
        local function get_field(f)
        if not f then return nil end
            local ok, val = pcall(f)
            if ok and val then
                return val
                end
                return nil
                end

                --------------------------------------------------------------------
                -- Internal state (unchanged)
                --------------------------------------------------------------------
                local stats = {
                    packet_count = 0,
                    protocols    = {},
                    endpoints    = { src = {}, dst = {} },
                    dns = {
                        queries   = 0,
                        responses = 0,
                        qtypes    = {},
                        rcodes    = {},
                        names     = {},
                    },
                    http = {
                        methods     = {},
                        hosts       = {},
                        status      = {},
                        uris        = {},
                        user_agents = {},
                    },
                    tls = {
                        versions = {},
                        sni      = {},
                        alpn     = {},
                        ciphers  = {},
                    },
                    tcp = {
                        streams       = {},
                        conversations = {},
                    },
                }

                --------------------------------------------------------------------
                -- Helpers
                --------------------------------------------------------------------
                local function increment(tbl, key, amount)
                amount = amount or 1
                if key == nil then return end
                    key = tostring(key)
                    tbl[key] = (tbl[key] or 0) + amount
                    end

                    local function get_top_n(tbl, n)
                    local list = {}
                    for k, v in pairs(tbl) do
                        table.insert(list, { key = k, count = v })
                        end
                        table.sort(list, function(a, b) return a.count > b.count end)
                        local result = {}
                        for i = 1, math.min(n, #list) do
                            result[i] = list[i]
                            end
                            return result
                            end

                            local function format_table(title, top_list, width)
                            width = width or 40
                            local lines = { string.format("=== %s ===", title) }
                            if #top_list == 0 then
                                table.insert(lines, "  (none)")
                                else
                                    for i, item in ipairs(top_list) do
                                        table.insert(lines, string.format("  %3d. %-" .. width .. "s  %8d",
                                                                          i, item.key, item.count))
                                        end
                                        end
                                        table.insert(lines, "")
                                        return table.concat(lines, "\n")
                                        end

                                        --------------------------------------------------------------------
                                        -- Packet listener
                                        --------------------------------------------------------------------
                                        local tap = Listener.new(nil, nil)

                                        function tap.packet(pinfo, tvb)
                                        stats.packet_count = stats.packet_count + 1

                                        -- Protocol counters
                                        local protos = get_field(f_frame_protocols)
                                        if protos then
                                            for proto in tostring(protos):gmatch("[^:]+") do
                                                increment(stats.protocols, proto)
                                                end
                                                end

                                                -- Endpoints
                                                local src = get_field(f_ip_src) or get_field(f_ipv6_src) or get_field(f_eth_src)
                                                local dst = get_field(f_ip_dst) or get_field(f_ipv6_dst) or get_field(f_eth_dst)
                                                if src then increment(stats.endpoints.src, tostring(src)) end
                                                    if dst then increment(stats.endpoints.dst, tostring(dst)) end

                                                        -- DNS
                                                        if p_stats.prefs.enable_dns then
                                                            local is_resp = get_field(f_dns_flags_response)
                                                            if is_resp then
                                                                local resp_str = tostring(is_resp)
                                                                if resp_str == "1" or resp_str == "True" then
                                                                    stats.dns.responses = stats.dns.responses + 1
                                                                    local rcode = get_field(f_dns_flags_rcode)
                                                                    if rcode then increment(stats.dns.rcodes, tostring(rcode)) end
                                                                        else
                                                                            stats.dns.queries = stats.dns.queries + 1
                                                                            end
                                                                            end
                                                                            local qname = get_field(f_dns_qry_name)
                                                                            if qname then increment(stats.dns.names, tostring(qname)) end
                                                                                local qtype = get_field(f_dns_qry_type)
                                                                                if qtype then increment(stats.dns.qtypes, tostring(qtype)) end
                                                                                    end

                                                                                    -- HTTP
                                                                                    if p_stats.prefs.enable_http then
                                                                                        local method = get_field(f_http_request_method)
                                                                                        if method then
                                                                                            increment(stats.http.methods, tostring(method))
                                                                                            local host = get_field(f_http_host)
                                                                                            if host then increment(stats.http.hosts, tostring(host)) end
                                                                                                local uri = get_field(f_http_request_uri)
                                                                                                if uri then increment(stats.http.uris, tostring(uri)) end
                                                                                                    local ua = get_field(f_http_user_agent)
                                                                                                    if ua then increment(stats.http.user_agents, tostring(ua)) end
                                                                                                        end
                                                                                                        local code = get_field(f_http_response_code)
                                                                                                        if code then increment(stats.http.status, tostring(code)) end
                                                                                                            end

                                                                                                            -- TLS
                                                                                                            if p_stats.prefs.enable_tls then
                                                                                                                local ver = get_field(f_tls_handshake_version)
                                                                                                                if ver then increment(stats.tls.versions, tostring(ver)) end
                                                                                                                    local sni = get_field(f_tls_sni)
                                                                                                                    if sni then increment(stats.tls.sni, tostring(sni)) end
                                                                                                                        local alpn = get_field(f_tls_alpn)
                                                                                                                        if alpn then increment(stats.tls.alpn, tostring(alpn)) end
                                                                                                                            local cipher = get_field(f_tls_cipher)
                                                                                                                            if cipher then increment(stats.tls.ciphers, tostring(cipher)) end
                                                                                                                                end

                                                                                                                                -- TCP streams / conversations
                                                                                                                                if p_stats.prefs.enable_tcp then
                                                                                                                                    local stream_id = get_field(f_tcp_stream)
                                                                                                                                    if stream_id then
                                                                                                                                        local sid = tostring(stream_id)
                                                                                                                                        local entry = stats.tcp.streams[sid]
                                                                                                                                        if not entry then
                                                                                                                                            entry = {
                                                                                                                                                pkts  = 0,
                                                                                                                                                bytes = 0,
                                                                                                                                                src   = tostring(src or "?"),
                                                                                                                                                dst   = tostring(dst or "?"),
                                                                                                                                                sport = tostring(get_field(f_tcp_srcport) or "?"),
                                                                                                                                                dport = tostring(get_field(f_tcp_dstport) or "?"),
                                                                                                                                            }
                                                                                                                                            stats.tcp.streams[sid] = entry
                                                                                                                                            end
                                                                                                                                            entry.pkts = entry.pkts + 1
                                                                                                                                            local len = get_field(f_tcp_len)
                                                                                                                                            if len then
                                                                                                                                                entry.bytes = entry.bytes + (tonumber(tostring(len)) or 0)
                                                                                                                                                end

                                                                                                                                                local a = entry.src .. ":" .. entry.sport
                                                                                                                                                local b = entry.dst .. ":" .. entry.dport
                                                                                                                                                local conv = (a < b) and (a .. " <-> " .. b) or (b .. " <-> " .. a)
                                                                                                                                                increment(stats.tcp.conversations, conv)
                                                                                                                                                end
                                                                                                                                                end
                                                                                                                                                end

                                                                                                                                                function tap.reset()
                                                                                                                                                stats.packet_count = 0
                                                                                                                                                stats.protocols    = {}
                                                                                                                                                stats.endpoints    = { src = {}, dst = {} }
                                                                                                                                                stats.dns = { queries = 0, responses = 0, qtypes = {}, rcodes = {}, names = {} }
                                                                                                                                                stats.http = { methods = {}, hosts = {}, status = {}, uris = {}, user_agents = {} }
                                                                                                                                                stats.tls  = { versions = {}, sni = {}, alpn = {}, ciphers = {} }
                                                                                                                                                stats.tcp  = { streams = {}, conversations = {} }
                                                                                                                                                end

                                                                                                                                                --------------------------------------------------------------------
                                                                                                                                                -- Report generation (unchanged logic)
                                                                                                                                                --------------------------------------------------------------------
                                                                                                                                                local function build_report(top_n)
                                                                                                                                                top_n = top_n or p_stats.prefs.top_n
                                                                                                                                                local out = {
                                                                                                                                                    "============================================================",
                                                                                                                                                    "  Advanced Wireshark Statistics Report",
                                                                                                                                                    "  Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
                                                                                                                                                    "============================================================",
                                                                                                                                                    "",
                                                                                                                                                    string.format("Total packets processed : %d", stats.packet_count),
                                                                                                                                                    "",
                                                                                                                                                }

                                                                                                                                                table.insert(out, format_table("Top Protocols", get_top_n(stats.protocols, top_n)))
                                                                                                                                                table.insert(out, format_table("Top Source Endpoints", get_top_n(stats.endpoints.src, top_n)))
                                                                                                                                                table.insert(out, format_table("Top Destination Endpoints", get_top_n(stats.endpoints.dst, top_n)))

                                                                                                                                                if p_stats.prefs.enable_dns then
                                                                                                                                                    table.insert(out, string.format("DNS Queries   : %d", stats.dns.queries))
                                                                                                                                                    table.insert(out, string.format("DNS Responses : %d", stats.dns.responses))
                                                                                                                                                    table.insert(out, "")
                                                                                                                                                    table.insert(out, format_table("Top DNS Query Types", get_top_n(stats.dns.qtypes, top_n)))
                                                                                                                                                    table.insert(out, format_table("Top DNS Response Codes", get_top_n(stats.dns.rcodes, top_n)))
                                                                                                                                                    table.insert(out, format_table("Top DNS Names", get_top_n(stats.dns.names, top_n), 50))
                                                                                                                                                    end

                                                                                                                                                    if p_stats.prefs.enable_http then
                                                                                                                                                        table.insert(out, format_table("HTTP Methods", get_top_n(stats.http.methods, top_n)))
                                                                                                                                                        table.insert(out, format_table("Top HTTP Hosts", get_top_n(stats.http.hosts, top_n), 40))
                                                                                                                                                        table.insert(out, format_table("HTTP Status Codes", get_top_n(stats.http.status, top_n)))
                                                                                                                                                        table.insert(out, format_table("Top HTTP URIs", get_top_n(stats.http.uris, top_n), 60))
                                                                                                                                                        table.insert(out, format_table("Top User-Agents", get_top_n(stats.http.user_agents, top_n), 50))
                                                                                                                                                        end

                                                                                                                                                        if p_stats.prefs.enable_tls then
                                                                                                                                                            table.insert(out, format_table("TLS Versions", get_top_n(stats.tls.versions, top_n)))
                                                                                                                                                            table.insert(out, format_table("Top TLS SNI", get_top_n(stats.tls.sni, top_n), 40))
                                                                                                                                                            table.insert(out, format_table("TLS ALPN", get_top_n(stats.tls.alpn, top_n)))
                                                                                                                                                            table.insert(out, format_table("TLS Cipher Suites", get_top_n(stats.tls.ciphers, top_n), 50))
                                                                                                                                                            end

                                                                                                                                                            if p_stats.prefs.enable_tcp then
                                                                                                                                                                local stream_list = {}
                                                                                                                                                                for sid, e in pairs(stats.tcp.streams) do
                                                                                                                                                                    table.insert(stream_list, {
                                                                                                                                                                        key   = string.format("stream %s  %s:%s → %s:%s",
                                                                                                                                                                                              sid, e.src, e.sport, e.dst, e.dport),
                                                                                                                                                                                              count = e.pkts,
                                                                                                                                                                                              bytes = e.bytes,
                                                                                                                                                                    })
                                                                                                                                                                    end
                                                                                                                                                                    table.sort(stream_list, function(a, b) return a.count > b.count end)

                                                                                                                                                                    table.insert(out, "=== Top TCP Streams (by packet count) ===")
                                                                                                                                                                    for i = 1, math.min(top_n, #stream_list) do
                                                                                                                                                                        local s = stream_list[i]
                                                                                                                                                                        table.insert(out, string.format("  %3d. %-55s  pkts=%6d  bytes=%10d",
                                                                                                                                                                                                        i, s.key, s.count, s.bytes or 0))
                                                                                                                                                                        end
                                                                                                                                                                        table.insert(out, "")
                                                                                                                                                                        table.insert(out, format_table("Top TCP Conversations",
                                                                                                                                                                                                       get_top_n(stats.tcp.conversations, top_n), 55))
                                                                                                                                                                        end

                                                                                                                                                                        table.insert(out, "============================================================")
                                                                                                                                                                        table.insert(out, "  End of report")
                                                                                                                                                                        table.insert(out, "============================================================")
                                                                                                                                                                        return table.concat(out, "\n")
                                                                                                                                                                        end

                                                                                                                                                                        --------------------------------------------------------------------
                                                                                                                                                                        -- CSV export (unchanged)
                                                                                                                                                                        --------------------------------------------------------------------
                                                                                                                                                                        local function write_csv(path)
                                                                                                                                                                        if not path or path == "" then
                                                                                                                                                                            return false, "CSV path empty"
                                                                                                                                                                            end
                                                                                                                                                                            local f, err = io.open(path, "w")
                                                                                                                                                                            if not f then return false, err end

                                                                                                                                                                                local function write_section(name, tbl)
                                                                                                                                                                                f:write("\n# " .. name .. "\n")
                                                                                                                                                                                f:write("key,count\n")
                                                                                                                                                                                for _, item in ipairs(get_top_n(tbl, 1000)) do
                                                                                                                                                                                    local k = tostring(item.key):gsub('"', '""')
                                                                                                                                                                                    f:write(string.format('"%s",%d\n', k, item.count))
                                                                                                                                                                                    end
                                                                                                                                                                                    end

                                                                                                                                                                                    f:write("# Advanced Stats CSV Export\n")
                                                                                                                                                                                    f:write(string.format("# Generated %s\n", os.date("%Y-%m-%d %H:%M:%S")))
                                                                                                                                                                                    f:write(string.format("# Total packets,%d\n", stats.packet_count))

                                                                                                                                                                                    write_section("Protocols", stats.protocols)
                                                                                                                                                                                    write_section("Source Endpoints", stats.endpoints.src)
                                                                                                                                                                                    write_section("Destination Endpoints", stats.endpoints.dst)

                                                                                                                                                                                    if p_stats.prefs.enable_dns then
                                                                                                                                                                                        write_section("DNS Query Types", stats.dns.qtypes)
                                                                                                                                                                                        write_section("DNS Response Codes", stats.dns.rcodes)
                                                                                                                                                                                        write_section("DNS Names", stats.dns.names)
                                                                                                                                                                                        end
                                                                                                                                                                                        if p_stats.prefs.enable_http then
                                                                                                                                                                                            write_section("HTTP Methods", stats.http.methods)
                                                                                                                                                                                            write_section("HTTP Hosts", stats.http.hosts)
                                                                                                                                                                                            write_section("HTTP Status", stats.http.status)
                                                                                                                                                                                            write_section("HTTP URIs", stats.http.uris)
                                                                                                                                                                                            write_section("HTTP User-Agents", stats.http.user_agents)
                                                                                                                                                                                            end
                                                                                                                                                                                            if p_stats.prefs.enable_tls then
                                                                                                                                                                                                write_section("TLS Versions", stats.tls.versions)
                                                                                                                                                                                                write_section("TLS SNI", stats.tls.sni)
                                                                                                                                                                                                write_section("TLS ALPN", stats.tls.alpn)
                                                                                                                                                                                                write_section("TLS Ciphers", stats.tls.ciphers)
                                                                                                                                                                                                end
                                                                                                                                                                                                if p_stats.prefs.enable_tcp then
                                                                                                                                                                                                    write_section("TCP Conversations", stats.tcp.conversations)
                                                                                                                                                                                                    f:write("\n# TCP Streams\n")
                                                                                                                                                                                                    f:write("stream_id,src,sport,dst,dport,packets,bytes\n")
                                                                                                                                                                                                    for sid, e in pairs(stats.tcp.streams) do
                                                                                                                                                                                                        f:write(string.format("%s,%s,%s,%s,%s,%d,%d\n",
                                                                                                                                                                                                                              sid, e.src, e.sport, e.dst, e.dport, e.pkts, e.bytes or 0))
                                                                                                                                                                                                        end
                                                                                                                                                                                                        end

                                                                                                                                                                                                        f:close()
                                                                                                                                                                                                        return true
                                                                                                                                                                                                        end

                                                                                                                                                                                                        --------------------------------------------------------------------
                                                                                                                                                                                                        -- Public entry point
                                                                                                                                                                                                        --------------------------------------------------------------------
                                                                                                                                                                                                        function advanced_stats_report()
                                                                                                                                                                                                        local report = build_report(p_stats.prefs.top_n)
                                                                                                                                                                                                        print(report)

                                                                                                                                                                                                        local csv_path = p_stats.prefs.csv_path
                                                                                                                                                                                                        if csv_path and csv_path ~= "" then
                                                                                                                                                                                                            local ok, err = write_csv(csv_path)
                                                                                                                                                                                                            if ok then
                                                                                                                                                                                                                print("\n[+] CSV written to: " .. csv_path)
                                                                                                                                                                                                                else
                                                                                                                                                                                                                    print("\n[!] CSV write failed: " .. tostring(err))
                                                                                                                                                                                                                    end
                                                                                                                                                                                                                    end
                                                                                                                                                                                                                    end

                                                                                                                                                                                                                    --------------------------------------------------------------------
                                                                                                                                                                                                                    -- Menu registration
                                                                                                                                                                                                                    --------------------------------------------------------------------
                                                                                                                                                                                                                    register_menu("Advanced Stats Report", advanced_stats_report, MENU_TOOLS_UNSORTED)

                                                                                                                                                                                                                    print("[advanced_stats] Plugin loaded – Tools → Advanced Stats Report")
