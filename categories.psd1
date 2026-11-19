# The site's four big categories, one per source folder of VpnHood, in its order: what each is for, its small drawing
# for the home page's card (Art), its picture for the API reference's front page (Image; a category without one shows its
# text alone), both files of images/, and the real-world things a developer builds with it.
# build.ps1 groups the packages and the API by them; the home page and the API reference's front page show them. A
# scenario names the packages it uses; each must be on the site.
#
# Groups: a category's groups of packages, in their order, each with a page of its own and a card on the Libraries page.
# A group is one project and the projects under it: those whose name's third segment is its Segment, as in
# VpnHood.Net.<Segment>..., so the docs keep the projects' hierarchy (owner, 2026-11-13: "in doc hirarchy, keep project
# hirarchy"). Text is its line on the card; Intro says what it is for, Use when to use it, Pick which package to take; a
# Diagram is a section of its own under the intro, with its title, picture and text. A layer's own contract project is
# its category's first group, named just Abstraction ("dont say engine abstraction or logic abstraction, move it on top
# of the list and just say abstraction"): its card has a dashed border, as its drawing has. A code name in backticks in
# Use or Pick links to its API page.
@{
    Categories = @(
        @{
            Key = 'net'; Folder = 'Net'; Title = 'Networking'; Image = 'images/category-networking.svg'
            Art = 'images/part-networking.svg'
            ImageAlt = 'A device''s IP packets go into a TUN adapter, and the TCP stack hands your code streams'
            Intro = 'Standalone .NET libraries for the network layer a VPN is built on. None of them needs a VPN: each one works in any .NET application.'
            Scenarios = @(
                @{ Title = 'Capture a device''s traffic'
                   Text = 'Open a TUN adapter on Windows, Linux, Android or iOS, and read and write the IP packets the system routes into it.'
                   Packages = @('VpnHood.Net.VpnAdapters.Abstractions', 'VpnHood.Net.VpnAdapters.WinTun', 'VpnHood.Net.VpnAdapters.LinuxTun') }
                @{ Title = 'Read and build IP packets'
                   Text = 'Parse IPv4 and IPv6 packets with their TCP, UDP and ICMP parts, build replies and fix checksums, in pooled memory.'
                   Packages = @('VpnHood.Net.Packets') }
                @{ Title = 'Turn packets into streams'
                   Text = 'A user-space TCP stack ends the TCP connections carried in raw packets and gives you each one as a Stream.'
                   Packages = @('VpnHood.Net.TcpStack') }
                @{ Title = 'Go through a proxy, or be one'
                   Text = 'SOCKS5, SOCKS4 and HTTP(S) proxy clients and servers, with authentication and UDP.'
                   Packages = @('VpnHood.Net.Proxies') }
                @{ Title = 'Locate an IP address'
                   Text = 'The country of an address, from online services or a local database.'
                   Packages = @('VpnHood.Net.IpLocations') }
            )
            Groups = @(
                @{ Name = 'VPN adapters'; Segment = 'VpnAdapters'; Art = 'images/part-networking.svg'
                   Text = 'A virtual network interface on Windows, Linux, Android and iOS, behind one API.'
                   Intro = 'A VPN adapter is the virtual network interface a VPN reads packets from and writes them to. Every platform''s adapter implements the same contract, so code written against it runs on all of them.'
                   Use = @(
                       'You capture a device''s traffic to tunnel it, inspect it or filter it.'
                       'You write a VPN client, a firewall or a traffic monitor in .NET.'
                       'You want one code path on every platform: write it against `IVpnAdapter`, and pick the platform''s adapter when the app starts.')
                   Pick = @(
                       'Windows: WinTun for an app or a service; WindowsVpnPlugin for an app that runs from an MSIX package; WinDivert to capture traffic without an interface of its own.'
                       'Linux: LinuxTun. Android: AndroidTun, in your VpnService. iOS and tvOS: IosTun, in your packet tunnel extension.'
                       'Code that only takes an adapter, and tests: VpnAdapters.Abstractions, with its null adapter.') }
                @{ Name = 'Packets'; Segment = 'Packets'; Art = 'images/group-packets.svg'
                   Text = 'Read and build IPv4 and IPv6 packets, with their TCP, UDP and ICMP parts.'
                   Intro = 'A fast, memory-efficient reader and builder of IP packets - IPv4, IPv6, ICMPv4, ICMPv6, TCP and UDP - in pooled memory.'
                   Use = @(
                       'You read the packets a VPN adapter hands you, or build the replies it sends.'
                       'You change addresses or ports as packets pass through, and fix their checksums.') }
                @{ Name = 'Packet transports'; Segment = 'PacketTransports'; Art = 'images/group-packet-transports.svg'
                   Text = 'Two-way channels of IP packets, with send queues, batching and a fair queue.'
                   Intro = 'Packet queues for any channel of IP packets - a device, a socket, a pipe: a transport takes packets from many senders, queues them and hands them to your code on a sending loop of its own. It is how VpnHood moves packets between its tunnels, its adapters and its TCP stack.'
                   Use = @(
                       'You write a channel of IP packets, over a device, a socket or a pipe, and want its queue, its sending loop and the packets'' ownership done for you.'
                       'Several flows share one link, and one that floods may not starve the rest: the fair queue keeps it mostly in its own lane.') }
                @{ Name = 'TCP stack'; Segment = 'TcpStack'; Art = 'images/group-tcp-stack.svg'
                   Text = 'Turn the TCP connections inside raw packets into .NET streams.'
                   Intro = 'A lightweight user-space TCP stack: it ends the TCP connections carried in raw IP packets, from a TUN or WinDivert adapter, and gives you each one as a stream.'
                   Use = @(
                       'You capture packets and want each TCP connection as a stream: to proxy it, inspect it or send it somewhere else.'
                       'Your code takes a stack without depending on its implementation: reference TcpStack.Abstractions alone.')
                   Pick = @('TcpStack for the stack; TcpStack.Abstractions for its interfaces only.') }
                @{ Name = 'QUIC'; Segment = 'Quic'; Art = 'images/group-quic.svg'
                   Text = 'One small QUIC API, with MsQuic, Android and iOS underneath.'
                   Intro = 'The QUIC surface VpnHood uses - clients, connections and streams - independent of any QUIC implementation. Each platform''s implementation is a package of its own.'
                   Use = @(
                       'You need QUIC on Windows, Linux, Android and iOS from one code path.'
                       'You want to change the QUIC implementation without touching the code that uses it.')
                   Pick = @(
                       'Windows and Linux: Quic.MsQuic, on System.Net.Quic.'
                       'Android: Quic.Android, over MsQuic.'
                       'iOS: Quic.Ios, on Apple''s Network.framework, iOS 15 and later.'
                       'Code that only uses QUIC: Quic.Abstractions.') }
                @{ Name = 'Proxies'; Segment = 'Proxies'; Art = 'images/group-proxies.svg'
                   Text = 'SOCKS5, SOCKS4 and HTTP(S) proxy clients and servers.'
                   Intro = 'Proxy clients and servers for SOCKS5, SOCKS4 and HTTP(S), with authentication and UDP.'
                   Use = @(
                       'Your app reaches the network through a SOCKS or HTTP proxy.'
                       'You run a small proxy server inside a .NET app.') }
                @{ Name = 'IP locations'; Segment = 'IpLocations'; Art = 'images/group-ip-locations.svg'
                   Text = 'Find the country of an IP address, online or from a local database.'
                   Intro = 'Finds where an IP address is: online providers (ipapi.co, ipinfo.io, ip2location.io, Cloudflare), a local database of country ranges, and composites that try them in turn.'
                   Use = @(
                       'You show users where they connect from.'
                       'You split traffic by country and need each address''s country without going online.')
                   Pick = @(
                       'Net.IpLocations: the providers and the composites.'
                       'Net.IpLocations.Providers.SqliteProvider: an offline range database in SQLite.') }
                @{ Name = 'Toolkit'; Segment = 'Toolkit'; Art = 'images/group-toolkit.svg'
                   Text = 'General-purpose helpers for any .NET project.'
                   Intro = 'General-purpose .NET helpers, used across VpnHood and usable in any project: IP networks and ranges, collections, streams, JSON converters, API clients, jobs and trackers.'
                   Use = @('You want the helpers VpnHood uses - IP networks and ranges, streams, JSON converters - in your own code.') }
            )
        }
        @{
            Key = 'core'; Folder = 'Core'; Title = 'VPN Core'; Image = 'images/category-core.svg'
            Art = 'images/part-core.svg'
            ImageAlt = 'A client, the encrypted tunnel to the server whose access manager admits it, and traffic split off around the tunnel'
            Intro = 'The VPN itself: the client and server engines, the tunnel between them, and the parts that decide where traffic goes and who may connect.'
            Scenarios = @(
                @{ Title = 'Run your own VPN server'
                   Text = 'Host a VpnHood server on your own machine, with its access keys kept in files and no control panel.'
                   Packages = @('VpnHood.Core.Server', 'VpnHood.Core.Server.Access.Managers.FileAccessManagers') }
                @{ Title = 'Connect from your own code'
                   Text = 'The client finds a server from an access key, builds a session with it, and runs the tunnel on a VPN adapter.'
                   Packages = @('VpnHood.Core.Client') }
                @{ Title = 'Split the tunnel'
                   Text = 'Send traffic around the VPN by country, IP range or domain, with filters on the client or the server.'
                   Packages = @('VpnHood.Core.Filtering.Abstractions', 'VpnHood.Core.Filtering.Sqlite', 'VpnHood.Core.Filtering.DomainFiltering') }
                @{ Title = 'Decide who connects'
                   Text = 'Write your own access manager: it admits sessions, counts their traffic and configures the server.'
                   Packages = @('VpnHood.Core.Server.Access') }
                @{ Title = 'Reach servers through proxies'
                   Text = 'Connect through one proxy, or a managed list that rates and rotates its endpoints.'
                   Packages = @('VpnHood.Core.Proxies.Management') }
            )
            Groups = @(
                @{ Name = 'Abstraction'; Segment = 'Common'; Abstraction = $true; Art = 'images/group-core-abstraction.svg'
                   Text = 'What the engine''s parts agree on, with no engine inside.'
                   Intro = 'The types a VpnHood client, server and access manager share, without the engine: access keys and server tokens, access and usage, client policies, and their errors.'
                   Use = @(
                       'Your code reads access keys or server tokens, or handles the engine''s errors, without depending on the engine: a UI, a tool or an access manager.'
                       'You write an access manager, and need the types it shares with the server.') }
                @{ Name = 'Client'; Segment = 'Client'; Art = 'images/part-core.svg'
                   Text = 'The client engine, the VPN service that runs it, each platform''s device, and their contracts.'
                   Intro = 'The VpnHood client engine finds a server, builds a session with it, and runs the session''s tunnel on a VPN adapter. Around it: the VPN service that runs the engine on each platform, and the device provider through which the app starts that service. Each has a contract of its own, for code that must not depend on it.'
                   Use = @(
                       'You connect to VpnHood servers from your own code, without VpnHood''s app.'
                       'You build an app layer of your own on the engine.'
                       'To build a whole VPN app, start from VpnHood.AppLogic.App or the template instead: they put these together for you.')
                   Pick = @(
                       'The engine: Core.Client.'
                       'The VPN service, on the side that runs the engine: Core.Client.VpnServices.Host, with the host for your platform - Android, iOS, Linux, WindowsTun or WindowsVpnPlugin.'
                       'The app''s side of that service: Core.Client.VpnServices.Manager, with the device provider for your platform (Core.Client.Devices).'
                       'Code that must not depend on the engine, such as a UI: Core.Client.Abstractions, for a connection''s options, the client''s state, its DNS and the errors a connection ends with; Core.Client.VpnServices.Abstractions, for the requests an app sends its VPN service and the connection info it gets back.') }
                @{ Name = 'Server'; Segment = 'Server'; Art = 'images/group-server.svg'
                   Text = 'Run a VpnHood server, with its access keys in files or in the MANAGER.'
                   Intro = 'The VpnHood server engine takes its configuration from its access manager, listens for clients and carries their sessions. The access manager admits sessions, counts their traffic and configures the server.'
                   Use = @(
                       'You host a VpnHood server on your own machine.'
                       'You decide who may connect: write your own access manager, or keep access keys in files.')
                   Pick = @(
                       'Core.Server: the server engine.'
                       'Core.Server.Access: the access manager a server answers to, and the client of the MANAGER''s agent API.'
                       'Core.Server.Access.Managers.FileAccessManagers: access keys and sessions in files, for a server without the MANAGER.') }
                @{ Name = 'Tunneling'; Segment = 'Tunneling'; Art = 'images/group-tunneling.svg'
                   Text = 'The tunnel a client and a server share.'
                   Intro = 'The tunnel between a VpnHood client and server, which both share: its requests, its streams, and the forwarding of a session''s packets.'
                   Use = @('You extend the tunnel between a VpnHood client and server. A client or a server brings it in on its own: Core.Client and Core.Server reference it.') }
                @{ Name = 'Filtering'; Segment = 'Filtering'; Art = 'images/group-filtering.svg'
                   Text = 'Decide which traffic goes through the tunnel: by IP range, country or domain.'
                   Intro = 'The filters a VpnHood client or server applies to its flows: pipes of IP and domain filters, and an IP mapper. Lists of IP ranges and domains can live in SQLite, and a domain is matched by the server name in each TLS connection.'
                   Use = @(
                       'You split the tunnel: some traffic goes through the VPN, and the rest goes straight out.'
                       'A server blocks or allows destinations.')
                   Pick = @(
                       'Core.Filtering.Abstractions: the filter pipes, with in-memory implementations.'
                       'Core.Filtering.Sqlite: IP range and domain lists in SQLite, for split country, split IP and split domain.'
                       'Core.Filtering.DomainFiltering: domains, by the SNI of each TLS connection.') }
                @{ Name = 'Proxy management'; Segment = 'Proxies'; Art = 'images/group-proxy-management.svg'
                   Text = 'Put the client''s tunnel inside a proxy: one proxy, or a managed list that rates and rotates them.'
                   Intro = 'A VpnHood client can optionally put its tunnel inside a proxy: it reaches its server through a SOCKS4, SOCKS5 or HTTP(S) proxy instead of going straight to it. The proxy only relays the encrypted tunnel and cannot see inside. These packages give the client one proxy, or a managed list of endpoints that are rated and rotated, kept in a store and updated from a URL.'
                   Diagram = @{ Title = 'What goes through the proxy'; Image = 'images/diagram-proxy-tunnels.svg'
                       ImageAlt = 'The client''s TCP connections reach its server each through a proxy; UDP and QUIC are off while a proxy is on'
                       Text = @(
                           'Every TCP connection the client makes to its server goes through a proxy: its requests and the TCP channels of its tunnel. Each connection can take a different proxy of the list.'
                           'While the client has a proxy connector, its tunnel takes TCP alone, whatever channel protocol it asks for: UDP and QUIC would reach the server''s address straight, around the proxies. The session''s SessionInfo.ChannelProtocols then holds TCP alone.') }
                   Use = @(
                       'A network blocks your server''s address: the client puts its tunnel inside a proxy and reaches the server through it.'
                       'You keep a list of proxies up to date from a URL, and the client uses the best of them.')
                   Pick = @(
                       'Core.Proxies.Management: the connectors.'
                       'Core.Proxies.Management.Abstractions: the connector''s contract, proxy endpoints and their parsing, and the list''s store.'
                       'Core.Proxies.Management.Sqlite: a shared endpoint store in SQLite.') }
            )
        }
        @{
            Key = 'applib'; Folder = 'AppLogic'; Title = 'App Logic'; Image = 'images/category-applib.svg'
            Art = 'images/part-applib.svg'
            ImageAlt = 'The app''s core, with its access keys, billing, updates, ads, accounts and settings around it'
            Intro = 'Everything a VPN app does below its screens, the same on every platform. Your app adds the screens and a head for each platform, as the template does.'
            Scenarios = @(
                @{ Title = 'A VPN app without its screens'
                   Text = 'Connecting, servers and access keys, settings, profiles, accounts and ads, behind the API a UI reads the app through.'
                   Packages = @('VpnHood.AppLogic.App') }
                @{ Title = 'Sell premium'
                   Text = 'Billing through Google Play and the App Store, and accounts and web purchases through your portal.'
                   Packages = @('VpnHood.AppLogic.Stores.GooglePlay', 'VpnHood.AppLogic.Stores.AppStore', 'VpnHood.AppLogic.Portal') }
                @{ Title = 'Keep it updated'
                   Text = 'Updates from Google Play, the App Store and the Microsoft Store, or a website APK that downloads and installs its own.'
                   Packages = @('VpnHood.AppLogic.Stores.GooglePlay.Core', 'VpnHood.AppLogic.Stores.AppStore.Core', 'VpnHood.AppLogic.Stores.MicrosoftStore.Core', 'VpnHood.AppLogic.Stores.AndroidWeb') }
                @{ Title = 'Show ads'
                   Text = 'AdMob''s app-open, interstitial and rewarded ads, with Google''s consent form.'
                   Packages = @('VpnHood.AppLogic.Ads.AdMob.Android') }
                @{ Title = 'Run on every platform'
                   Text = 'Android, iOS and tvOS, Windows as a service or a VPN plug-in, and Linux as a root service.'
                   Packages = @('VpnHood.AppLogic.App.Android', 'VpnHood.AppLogic.App.Ios', 'VpnHood.AppLogic.App.WindowsTun', 'VpnHood.AppLogic.App.Linux') }
                @{ Title = 'Drive the app from anywhere'
                   Text = 'The app''s API over HTTP, for a web UI or a phone paired with the app.'
                   Packages = @('VpnHood.AppLogic.Api', 'VpnHood.AppLogic.Api.WebHost', 'VpnHood.AppLogic.Api.HttpClients') }
            )
            Groups = @(
                @{ Name = 'Abstraction'; Segment = 'Abstractions'; Abstraction = $true; Art = 'images/group-applib-abstraction.svg'
                   Text = 'What a head plugs into the app - accounts, billing, ads, updates - as interfaces.'
                   Intro = 'What a head supplies to the app, and the app uses without knowing the implementation: the account, billing, ad, device-UI, culture, updater and user-review providers. Interfaces and the shapes they exchange: no app, no engine, no UI.'
                   Use = @(
                       'You plug your own billing, sign-in, ads or updates into the app.'
                       'You write a provider package of your own, as the Stores and Ads packages are.') }
                @{ Name = 'App'; Segment = 'App'; Art = 'images/part-applib.svg'
                   Text = 'A whole VPN app without its screens, on every platform.'
                   Intro = 'The VpnHood app without its screens: connecting, servers and access keys, settings, accounts, ads, updates, and the API a UI reads the app through. Each platform has a package of its own; a head adds the platform and the UI.'
                   Use = @(
                       'You build your own VPN app: the template is built on these packages.'
                       'You keep VpnHood''s app logic and bring your own UI.')
                   Pick = @('AppLogic.App on every platform, with your platform''s package: App.Android, App.Ios for iOS and tvOS, App.Linux, App.WindowsTun, or App.WindowsVpnPlugin for an app that runs from an MSIX package.') }
                @{ Name = 'API'; Segment = 'Api'; Art = 'images/group-api.svg'
                   Text = 'The app''s API for any UI, in the same process or over HTTP.'
                   Intro = 'The six interfaces a UI reads the app through, with every shape they carry: state, features, settings and profiles. The app''s web hosts serve them over HTTP, and the HTTP clients answer them from anywhere else.'
                   Use = @(
                       'You write a UI for the app: it needs AppLogic.Api and nothing else of the app.'
                       'Your UI runs somewhere else: a paired browser, a WebAssembly head, another app, or a second VpnHood client on the network.')
                   Pick = @(
                       'AppLogic.Api: the interfaces and their shapes.'
                       'AppLogic.Api.WebHost: serve the API, and a web UI''s files, over HTTP.'
                       'AppLogic.Api.HttpClients: reach the app''s web host from somewhere else.') }
                @{ Name = 'Stores'; Segment = 'Stores'; Art = 'images/group-stores.svg'
                   Text = 'Billing, sign-in, updates and reviews through Google Play, the App Store and the Microsoft Store.'
                   Intro = 'Each store''s billing, sign-in, updates and in-app reviews for a VpnHood app, and self-updates for an APK handed out outside the stores.'
                   Use = @(
                       'You sell premium through Google Play or the App Store.'
                       'Your app updates itself and asks for reviews in the store it came from.')
                   Pick = @(
                       'Google Play: Stores.GooglePlay for billing and sign-in with Google; Stores.GooglePlay.Core for updates and reviews alone.'
                       'App Store: Stores.AppStore for billing and Sign in with Apple; Stores.AppStore.Core for updates and reviews alone.'
                       'Microsoft Store: Stores.MicrosoftStore.Core for updates and reviews.'
                       'Outside the stores: Stores.AndroidWeb, for an APK that downloads and installs its own updates. Never in a store''s build: it asks for a permission Google Play forbids for an app''s own updates.') }
                @{ Name = 'Ads'; Segment = 'Ads'; Art = 'images/group-ads.svg'
                   Text = 'AdMob''s app-open, interstitial and rewarded ads, with Google''s consent form.'
                   Intro = 'Google AdMob ads for VpnHood apps on Android: app-open, interstitial and rewarded ads, and the consent form of Google''s User Messaging Platform.'
                   Use = @('You show ads in your app on Android, for example in a free tier.') }
                @{ Name = 'Portal'; Segment = 'Portal'; Art = 'images/group-portal.svg'
                   Text = 'Accounts, sign-in and web purchases through the VpnHood Portal.'
                   Intro = 'Accounts, sign-in and web purchases for VpnHood apps, through the VpnHood Portal API.'
                   Use = @('Your app''s users sign in and buy on the web, through the VpnHood Portal.') }
            )
        }
        @{
            Key = 'apphosting'; Folder = 'AppHosting'; Title = 'App Hosting'; Image = 'images/category-apphosting.svg'
            Art = 'images/part-apphosting.svg'
            ImageAlt = 'One app UI hosted on a phone, a desktop and in a browser'
            Intro = 'The hosts that run a UI for the app on each platform, from a phone to a desktop service.'
            Scenarios = @(
                @{ Title = 'Use the ready UI'
                   Text = 'Host VpnHood''s Avalonia UI on Android, iOS, Windows and Linux, or in a browser.'
                   Packages = @('VpnHood.AppHosting.Avalonia', 'VpnHood.AppHosting.Avalonia.Android', 'VpnHood.AppHosting.Avalonia.Desktop') }
                @{ Title = 'Install on a desktop'
                   Text = 'The app runs as a machine service, systemd on Linux or a LocalSystem service on Windows, with a window for each person who signs in, and updates itself.'
                   Packages = @('VpnHood.AppHosting.Desktop.Daemon', 'VpnHood.AppHosting.Desktop.Linux', 'VpnHood.AppHosting.Desktop.WindowsTun') }
                @{ Title = 'Web views and MAUI'
                   Text = 'Host a web UI in a native web view on Android, iOS and Windows, or a .NET MAUI UI.'
                   Packages = @('VpnHood.AppHosting.WebView', 'VpnHood.AppHosting.Maui') }
            )
            Groups = @(
                @{ Name = 'Hosting'; Segment = 'AppHosting'; Art = 'images/part-apphosting.svg'
                   Text = 'Run a UI for the app - Avalonia, a web view or MAUI - on a phone, a desktop or in a browser.'
                   Intro = 'What runs a UI for the VpnHood app on each platform: an Avalonia UI on Android, iOS, the desktop and in a browser; a web UI in a native web view; or a .NET MAUI UI. On Windows and Linux the app can run as a machine service, with a window for each person who signs in.'
                   Use = @(
                       'You show VpnHood''s Avalonia UI, or an Avalonia UI of your own, on any platform.'
                       'Your UI is a web app, shown in a native web view.'
                       'You install the app on Windows or Linux as a machine service.')
                   Pick = @(
                       'Avalonia: AppHosting.Avalonia, with Avalonia.Android, Avalonia.Ios, Avalonia.Desktop or Avalonia.Browser.'
                       'A desktop service and its window: AppHosting.Desktop and Desktop.Daemon, with Desktop.Linux, Desktop.WindowsTun or Desktop.WindowsVpnPlugin. Desktop.Abstractions is what a desktop host and its UI agree on.'
                       'A web view: AppHosting.WebView, with WebView.Android, WebView.Ios or WebView.Windows.'
                       '.NET MAUI: AppHosting.Maui, on Android and Windows.') }
            )
        }
        @{
            Key = 'appui'; Folder = 'AppUi'; Title = 'App UI'; Image = 'images/category-appui.svg'
            Art = 'images/part-appui.svg'
            ImageAlt = 'The app UI: its look in two themes, and its words in every language'
            Intro = 'The app''s look and its words: what a person sees, and what any UI toolkit needs from the app.'
            Scenarios = @(
                @{ Title = 'Bring your own UI'
                   Text = 'Any UI toolkit gets the app''s state and its API in one place.'
                   Packages = @('VpnHood.AppUi.Common') }
                @{ Title = 'Speak every language'
                   Text = 'The words of every language the app speaks, right-to-left ones included, and the text for errors, dates, traffic and country names.'
                   Packages = @('VpnHood.AppUi.Common') }
            )
            Groups = @(
                @{ Name = 'Abstraction'; Segment = 'Common'; Abstraction = $true; Art = 'images/group-appui-abstraction.svg'
                   Text = 'The app as any UI toolkit sees it: its state, its words and their text.'
                   Intro = 'The VpnHood app as a UI sees it, for any UI toolkit: the app''s state and API in one place, the words of every language, and the code that turns the app''s state into text - errors, dates, traffic and country names. No toolkit, no theme, no picture.'
                   Use = @('You write a UI of your own, in Avalonia or another toolkit, and want the app''s state and every language''s words ready to show.') }
            )
        }
    )
}
