# The site's four big categories, one per source folder of VpnHood, in its order: what each is for, its picture (Image,
# a file of images/; a category without one shows its text alone), and the real-world things a developer builds with it.
# build.ps1 groups the packages and the API by them, and the API reference's front page shows them. A scenario names the
# packages it uses; each must be on the site.
@{
    Categories = @(
        @{
            Key = 'net'; Folder = 'Net'; Title = 'Networking'
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
        }
        @{
            Key = 'core'; Folder = 'Core'; Title = 'VPN Core'
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
        }
        @{
            Key = 'applib'; Folder = 'AppLib'; Title = 'App Logic'
            Intro = 'Everything a VPN app does below its screens, the same on every platform. Your app adds the screens and a head for each platform, as the template does.'
            Scenarios = @(
                @{ Title = 'A VPN app without its screens'
                   Text = 'Connecting, servers and access keys, settings, profiles, accounts and ads, behind the API a UI reads the app through.'
                   Packages = @('VpnHood.AppLib.App') }
                @{ Title = 'Sell premium'
                   Text = 'Billing through Google Play and the App Store, and accounts and web purchases through your portal.'
                   Packages = @('VpnHood.AppLib.Stores.GooglePlay', 'VpnHood.AppLib.Stores.AppStore', 'VpnHood.AppLib.Portal') }
                @{ Title = 'Keep it updated'
                   Text = 'Updates from Google Play, the App Store and the Microsoft Store, or a website APK that downloads and installs its own.'
                   Packages = @('VpnHood.AppLib.Stores.GooglePlay.Core', 'VpnHood.AppLib.Stores.AppStore.Core', 'VpnHood.AppLib.Stores.MicrosoftStore.Core', 'VpnHood.AppLib.Stores.AndroidWeb') }
                @{ Title = 'Show ads'
                   Text = 'AdMob''s app-open, interstitial and rewarded ads, with Google''s consent form.'
                   Packages = @('VpnHood.AppLib.Ads.AdMob.Android') }
                @{ Title = 'Run on every platform'
                   Text = 'Android, iOS and tvOS, Windows as a service or a VPN plug-in, and Linux as a root service.'
                   Packages = @('VpnHood.AppLib.App.Android', 'VpnHood.AppLib.App.Ios', 'VpnHood.AppLib.App.WindowsTun', 'VpnHood.AppLib.App.Linux') }
                @{ Title = 'Drive the app from anywhere'
                   Text = 'The app''s API over HTTP, for a web UI or a phone paired with the app.'
                   Packages = @('VpnHood.AppLib.Api', 'VpnHood.AppLib.Api.WebHost', 'VpnHood.AppLib.Api.HttpClients') }
            )
        }
        @{
            Key = 'appui'; Folder = 'AppUi'; Title = 'App UI'
            Intro = 'The app''s screens and the hosts that run them, from a phone to a desktop service.'
            Scenarios = @(
                @{ Title = 'Use the ready UI'
                   Text = 'Host VpnHood''s Avalonia UI on Android, iOS, Windows and Linux, or in a browser.'
                   Packages = @('VpnHood.AppUi.Hosting.Avalonia', 'VpnHood.AppUi.Hosting.Avalonia.Android', 'VpnHood.AppUi.Hosting.Avalonia.Desktop') }
                @{ Title = 'Install on a desktop'
                   Text = 'The app runs as a machine service, systemd on Linux or a LocalSystem service on Windows, with a window for each person who signs in, and updates itself.'
                   Packages = @('VpnHood.AppUi.Hosting.Desktop.Daemon', 'VpnHood.AppUi.Hosting.Desktop.Linux', 'VpnHood.AppUi.Hosting.Desktop.WindowsTun') }
                @{ Title = 'Bring your own UI'
                   Text = 'Any UI toolkit gets the app''s state, the words of every language, and the text for errors, dates and traffic.'
                   Packages = @('VpnHood.AppUi.Common') }
                @{ Title = 'Web views and MAUI'
                   Text = 'Host a web UI in a native web view on Android, iOS and Windows, or a .NET MAUI UI.'
                   Packages = @('VpnHood.AppUi.Hosting.WebView', 'VpnHood.AppUi.Hosting.Maui') }
            )
        }
    )
}
