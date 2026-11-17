// The MANAGER API's reference page (reference.md): Scalar, served from this site at the version build.ps1 pins, reading
// the site's copy of the API's description. Nothing reaches a third party: Scalar's telemetry, its fonts, its AI drawer
// and its MCP and SDK offers are off, and so is its test client, which would send requests with a reader's API key from
// this page. Its colours follow the site's theme and change with it, and its sidebar stays under the site's top bar, which
// DocFX keeps at the window's top (60px) from 768px wide.
(() => {
  const element = document.getElementById('vh-api-reference')
  const isDark = () => document.documentElement.getAttribute('data-bs-theme') === 'dark'

  // the site's own colours and fonts (main.css), for Scalar's light and dark modes
  const customCss = `
    .light-mode {
      --scalar-background-1: #fff; --scalar-background-2: #f5f5f5; --scalar-background-3: #f0f0f0;
      --scalar-color-1: #161616; --scalar-color-2: #505050; --scalar-color-accent: #0065b3;
      --scalar-border-color: #e6e6e6;
    }
    .dark-mode {
      --scalar-background-1: #1f1f1f; --scalar-background-2: #292929; --scalar-background-3: #333;
      --scalar-color-accent: #75b6e7; --scalar-border-color: #404040;
    }
    .scalar-app, .scalar-api-reference {
      --scalar-font: var(--bs-body-font-family); --scalar-font-code: var(--bs-font-monospace);
    }
    @media (min-width: 768px) {
      .scalar-api-reference { --scalar-custom-header-height: 60px; }
    }`

  const configuration = () => ({
    url: element.dataset.url,
    layout: 'modern',
    theme: 'default',
    customCss,
    withDefaultFonts: false,
    telemetry: false,
    agent: { disabled: true },
    mcp: { disabled: true },
    showDeveloperTools: 'never',
    hideClientButton: true,
    hideTestRequestButton: true,
    hideDarkModeToggle: true,
    forceDarkModeState: isDark() ? 'dark' : 'light',
    documentDownloadType: 'direct',
    defaultHttpClient: { targetKey: 'shell', clientKey: 'curl' }
  })

  const reference = Scalar.createApiReference(element, configuration())
  new MutationObserver(() => reference.updateConfiguration(configuration()))
    .observe(document.documentElement, { attributes: true, attributeFilter: ['data-bs-theme'] })
})()
