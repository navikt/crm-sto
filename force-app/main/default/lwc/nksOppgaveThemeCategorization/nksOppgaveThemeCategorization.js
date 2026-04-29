import { LightningElement, api, wire } from 'lwc';
import getCategorization from '@salesforce/apex/CRM_ThemeUtils.getCategorizationByThemeSet';

const THEME_SET = 'ARCHIVE_THEMES';

export default class NksOppgaveThemeCategorization extends LightningElement {
    @api disabled = false;

    gjelderMap;
    themeMap;
    chosenTheme;
    chosenGjelder;
    gjelderList;
    themes;
    _initialSubthemeCode;
    _initialSubtypeCode;

    @wire(getCategorization, { themeSet: THEME_SET })
    categoryResults({ data, error }) {
        if (data) {
            this.themeMap = data.themeMap;
            this.gjelderMap = data.gjelderMap;
            this.filterThemes();
            if (this.chosenTheme) {
                this.filterGjelder();
                this.resolveInitialGjelder();
            }
        } else if (error) {
            console.error('Problem on getCategorization(): ', JSON.stringify(error, null, 2));
        }
    }

    // #### EVENT HANDLERS ####
    handleThemeChange(event) {
        this.chosenTheme = event.detail.value;
        this.chosenGjelder = null;
        this.filterGjelder();
        this.dispatchEvent(new CustomEvent('change'));
    }

    handleGjelderChange(event) {
        this.chosenGjelder = event.detail.value;
        this.dispatchEvent(new CustomEvent('change'));
    }

    // #### PRIVATE FUNCTIONS ####
    filterThemes() {
        let returnThemes = [{ label: '(Ikke valgt)', value: '' }];
        let listThemes = [];
        if (this.themeMap) {
            // eslint-disable-next-line @salesforce/aura/ecma-intrinsics
            Object.values(this.themeMap).forEach((values) => {
                listThemes = [...listThemes, ...values];
            });
        }
        listThemes
            .filter((theme) => theme.CRM_Available__c)
            .forEach((theme) => {
                returnThemes.push({ label: theme.Name, value: theme.Id });
            });
        this.themes = returnThemes.sort((a, b) => a.label.localeCompare(b.label, 'nb'));
    }

    filterGjelder() {
        const listGjelder =
            this.chosenTheme && this.gjelderMap && this.chosenTheme in this.gjelderMap
                ? this.gjelderMap[this.chosenTheme]
                : [];
        const returnGjelder = listGjelder.length !== 0 ? [{ label: '(Ikke valgt)', value: '' }] : [];
        listGjelder.forEach((gjelder) => {
            returnGjelder.push({ label: gjelder.CRM_Display_Name__c, value: gjelder.Id });
        });
        this.gjelderList = returnGjelder;
    }

    resolveInitialGjelder() {
        if (!this.gjelderMap || !this.chosenTheme) return;
        if (!this._initialSubthemeCode && !this._initialSubtypeCode) return;
        const validGjelder = Object.prototype.hasOwnProperty.call(this.gjelderMap, this.chosenTheme)
            ? this.gjelderMap[this.chosenTheme]
            : [];
        for (let gjelder of validGjelder) {
            if (
                (this._initialSubthemeCode == null || gjelder.CRM_Subtheme_Code__c === this._initialSubthemeCode) &&
                (this._initialSubtypeCode == null || gjelder.CRM_Subtype_Code__c === this._initialSubtypeCode)
            ) {
                this.chosenGjelder = gjelder.Id;
                break;
            }
        }
    }

    // #### GETTERS / SETTERS ####
    @api
    get theme() {
        return this.chosenTheme;
    }
    set theme(themeValue) {
        this.chosenTheme = themeValue;
        if (this.gjelderMap) {
            this.filterGjelder();
            this.resolveInitialGjelder();
        }
    }

    @api
    get themeCode() {
        let themes = [];
        if (this.themeMap) {
            // eslint-disable-next-line @salesforce/aura/ecma-intrinsics
            Object.values(this.themeMap).forEach((values) => {
                themes = [...themes, ...values];
            });
        }
        return themes.find((t) => t.Id === this.chosenTheme)?.CRM_Code__c ?? '';
    }

    @api
    get subthemeCode() {
        if (!this.chosenGjelder || !this.gjelderMap || !this.chosenTheme) return '';
        const validGjelder = Object.prototype.hasOwnProperty.call(this.gjelderMap, this.chosenTheme)
            ? this.gjelderMap[this.chosenTheme]
            : [];
        return validGjelder.find((g) => g.Id === this.chosenGjelder)?.CRM_Subtheme_Code__c ?? '';
    }
    set subthemeCode(value) {
        this._initialSubthemeCode = value;
        this.resolveInitialGjelder();
    }

    @api
    get subtypeCode() {
        if (!this.chosenGjelder || !this.gjelderMap || !this.chosenTheme) return '';
        const validGjelder = Object.prototype.hasOwnProperty.call(this.gjelderMap, this.chosenTheme)
            ? this.gjelderMap[this.chosenTheme]
            : [];
        return validGjelder.find((g) => g.Id === this.chosenGjelder)?.CRM_Subtype_Code__c ?? '';
    }
    set subtypeCode(value) {
        this._initialSubtypeCode = value;
        this.resolveInitialGjelder();
    }

    get gjelderPlaceholder() {
        if (this.chosenTheme && this.gjelderMap) {
            return this.chosenTheme in this.gjelderMap ? '(Ikke valgt)' : '(Ingen undertema)';
        }
        return '(Ikke valgt)';
    }

    get gjelderDisabled() {
        return this.disabled || !this.chosenTheme || !this.gjelderMap || !(this.chosenTheme in this.gjelderMap);
    }
}
