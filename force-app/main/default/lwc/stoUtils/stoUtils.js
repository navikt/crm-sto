/**
 * Function for formating thread external name in format category / themeGroup
 * @param {string} thread external name
 * @returns {string} category / themeGroup
 */
export function getContentType(threadExternalName) {
    let parts = threadExternalName.split(' - ');

    if (parts.length < 2) {
        return threadExternalName;
    }

    let themeGroup = parts[0].trim();
    let category = parts[1].split(':')[0].trim();

    category = category.toLowerCase().replace(/\s+/g, '-');

    return `${category} / ${themeGroup}`;
}
