export function resolveNavUrls(value, hostname = window.location.hostname) {
    const isDev =
        hostname === 'dev.nav.no' || hostname.endsWith('.dev.nav.no') || hostname.endsWith('.scratch.my.site.com');

    if (!isDev || typeof value !== 'string') return value;

    return value.replace(
        /(https?:\/\/|\/\/)((?:[a-z0-9-]+\.)*nav\.no)(?=[:/?#\s"'<>]|$)/gi,
        (match, protocol, host) => {
            const domain = host.toLowerCase();
            if (domain === 'dev.nav.no' || domain.endsWith('.dev.nav.no')) return match;
            const devHost = domain === 'innboks.nav.no' ? 'innboks.dev.nav.no' : 'www.ansatt.dev.nav.no';
            return protocol + devHost;
        }
    );
}
