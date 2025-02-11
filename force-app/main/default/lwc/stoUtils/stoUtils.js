export const stoThemeMapping = {
    Arbeid: 'Arbeid',
    Familie: 'Familie og barn',
    Helse: 'Helse og sykdom',
    Internasjonal: 'Bor eller jobber i utlandet',
    Pensjon: 'Pensjon',
    Ufør: 'Ufør',
    Hjelpemidler: 'Hjelpemidler og tilrettelegging',
    Pleiepenger: 'Pleiepenger for sykt barn'
};

export function getSelectedThemeUI(subpath, selectedTheme) {
    if (subpath === '/skriv-til-oss/') {
        return stoThemeMapping[selectedTheme];
    }
    return selectedTheme;
}

export function getKeyFromValue(value) {
    return Object.keys(stoThemeMapping).find((key) => stoThemeMapping[key] === value) || null;
}

export function getPageType(threadType) {
    return threadType === 'STO' || threadType === 'STB'
        ? 'Srkiv til oss'
        : threadType === 'BTO'
        ? 'Beskjed til oss'
        : '';
}
