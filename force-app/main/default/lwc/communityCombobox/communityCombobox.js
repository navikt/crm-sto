import { LightningElement, api } from 'lwc';

let idCounter = 0;

export default class CommunityCombobox extends LightningElement {
    @api label = '';
    @api placeholder = '- Velg person -';
    @api options = [];
    @api value = '';
    @api required = false;
    @api invalid = false;
    @api errorMessage = '';

    isOpen = false;
    highlightedIndex = -1;
    baseId = `comboboxfield-${idCounter++}`;

    get inputId() {
        return this.baseId;
    }

    get listId() {
        return `${this.baseId}-filtered-options`;
    }

    get errorId() {
        return `${this.baseId}-error`;
    }

    get listHidden() {
        return !this.isOpen;
    }

    get listClass() {
        return `aksel-combobox__list${this.isOpen ? '' : ' aksel-combobox__list--closed'}`;
    }

    get displayValue() {
        const selected = (this.options || []).find((o) => o.value === this.value);
        return selected?.label || '';
    }

    get computedOptions() {
        return (this.options || []).map((o, index) => ({
            ...o,
            index,
            selected: o.value === this.value ? 'true' : 'false',
            domId: `${this.baseId}-option-${String(o.value).replace(/[^a-zA-Z0-9_-]/g, '-')}`
        }));
    }

    toggleList() {
        this.isOpen = !this.isOpen;

        if (this.isOpen) {
            const selectedIndex = this.computedOptions.findIndex((o) => o.value === this.value);
            this.highlightedIndex = selectedIndex >= 0 ? selectedIndex : 0;
        }
    }

    closeList() {
        this.isOpen = false;
        this.highlightedIndex = -1;
    }

    handleFocusOut(event) {
        const nextFocused = event.relatedTarget;
        if (!nextFocused || !this.template.contains(nextFocused)) {
            this.closeList();
        }
    }

    handleOptionClick(event) {
        const selectedValue = event.currentTarget.dataset.value;
        this.dispatchSelection(selectedValue);
    }

    handleInputKeydown(event) {
        const options = this.computedOptions;
        if (!options.length && (event.key === 'ArrowDown' || event.key === 'ArrowUp')) {
            event.preventDefault();
            return;
        }

        switch (event.key) {
            case 'Enter':
            case ' ':
                event.preventDefault();
                if (!this.isOpen) {
                    this.isOpen = true;
                    this.highlightedIndex = options.findIndex((o) => o.value === this.value);
                    if (this.highlightedIndex < 0) this.highlightedIndex = 0;
                } else if (this.highlightedIndex >= 0 && options[this.highlightedIndex]) {
                    this.dispatchSelection(options[this.highlightedIndex].value);
                }
                break;

            case 'Escape':
                event.preventDefault();
                this.closeList();
                break;

            case 'ArrowDown':
                event.preventDefault();
                if (!this.isOpen) {
                    this.isOpen = true;
                    this.highlightedIndex = 0;
                } else {
                    this.highlightedIndex = this.highlightedIndex < options.length - 1 ? this.highlightedIndex + 1 : 0;
                }
                break;

            case 'ArrowUp':
                event.preventDefault();
                if (!this.isOpen) {
                    this.isOpen = true;
                    this.highlightedIndex = options.length - 1;
                } else {
                    this.highlightedIndex = this.highlightedIndex > 0 ? this.highlightedIndex - 1 : options.length - 1;
                }
                break;

            case 'Tab':
                this.closeList();
                break;

            default:
                break;
        }
    }

    dispatchSelection(selectedValue) {
        this.closeList();

        this.dispatchEvent(
            new CustomEvent('selectionchange', {
                detail: { value: selectedValue }
            })
        );
    }
}
