import { createElement } from 'lwc';
import StoMessageInbox from 'c/stoMessageInbox';
import getInboxPage from '@salesforce/apex/stoInboxHelper.getAccessibleInboxPage';
import getNextInboxPage from '@salesforce/apex/stoInboxHelper.getNextInboxPage';
import getChildren from '@salesforce/apex/stoPersonContext.getRepresentableChildren';

jest.mock('@salesforce/apex/stoInboxHelper.getAccessibleInboxPage', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/stoInboxHelper.getNextInboxPage', () => ({ default: jest.fn() }), { virtual: true });
jest.mock(
    '@salesforce/apex/stoPersonContext.getRepresentableChildren',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/wire-service-jest-util');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    'c/inboxAmplitude',
    () => ({
        logNavigationEvent: jest.fn(),
        getComponentName: jest.fn(),
        setDecoratorParams: jest.fn()
    }),
    { virtual: true }
);
jest.mock('c/stoReadState', () => ({ READ_STATE_EVENT: 'storeadstatechange' }), { virtual: true });

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
const page = (ids, extra = {}) => ({
    recent: ids.map((recordId) => ({ recordId, category: 'Familie' })),
    older: [],
    hasMore: false,
    ...extra
});
const children = [
    { label: 'Beate', value: 'beate' },
    { label: 'Ola', value: 'ola' }
];

function select(element, value) {
    element.shadowRoot
        .querySelector('c-ds-combobox')
        .dispatchEvent(new CustomEvent('selectionchange', { detail: { value } }));
}

function displayedIds(element) {
    return [...element.shadowRoot.querySelectorAll('c-sto-message-inbox-item')].map((item) => item.thread.recordId);
}

afterEach(() => {
    document.body.innerHTML = '';
    jest.clearAllMocks();
});

it('loads the authorized full inbox again on focus instead of using a cached page', async () => {
    getInboxPage.mockResolvedValueOnce(page(['self-thread'])).mockResolvedValueOnce(page(['new-note', 'self-thread']));
    const element = createElement('c-sto-message-inbox', { is: StoMessageInbox });
    document.body.appendChild(element);
    await flush();
    expect(getInboxPage).toHaveBeenLastCalledWith({
        representedAccountId: null,
        beforeThreadId: null,
        beforeNoteId: null
    });
    window.dispatchEvent(new Event('focus'));
    await flush();
    expect(displayedIds(element)).toEqual(['new-note', 'self-thread']);
});

it('loads a verified child and ignores an earlier person response', async () => {
    let resolveBeate;
    getInboxPage
        .mockResolvedValueOnce(page([]))
        .mockImplementationOnce(() => new Promise((resolve) => (resolveBeate = resolve)))
        .mockResolvedValueOnce(page(['ola-thread', 'ola-note']));
    const element = createElement('c-sto-message-inbox', { is: StoMessageInbox });
    document.body.appendChild(element);
    getChildren.emit(children);
    await flush();
    select(element, 'beate');
    await flush();
    select(element, 'ola');
    await flush();
    resolveBeate(page(['beate-thread']));
    await flush();
    expect(displayedIds(element)).toEqual(['ola-thread', 'ola-note']);
    expect(getInboxPage).toHaveBeenLastCalledWith({
        representedAccountId: 'ola',
        beforeThreadId: null,
        beforeNoteId: null
    });
});

it('shows a sharing error rather than an empty or previous-person inbox', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => {});
    getInboxPage.mockResolvedValueOnce(page(['self-thread'])).mockRejectedValueOnce(new Error('Sharing denied'));
    const element = createElement('c-sto-message-inbox', { is: StoMessageInbox });
    document.body.appendChild(element);
    getChildren.emit(children);
    await flush();
    select(element, 'beate');
    await flush();
    expect(displayedIds(element)).toEqual([]);
    expect(element.shadowRoot.querySelector('.load-error')).not.toBeNull();
    expect(element.shadowRoot.textContent).not.toContain('Det finnes ingen meldinger');
    console.error.mockRestore();
});

it('passes both cursors and the same child to the authorized pagination endpoint', async () => {
    getInboxPage
        .mockResolvedValueOnce(page([]))
        .mockResolvedValueOnce(
            page(['thread-1'], { hasMore: true, beforeThreadId: 'thread-1', beforeNoteId: 'note-1' })
        );
    getNextInboxPage.mockResolvedValue(page(['thread-2', 'note-2']));
    const element = createElement('c-sto-message-inbox', { is: StoMessageInbox });
    document.body.appendChild(element);
    getChildren.emit(children);
    await flush();
    select(element, 'beate');
    await flush();
    element.shadowRoot.querySelector('button').click();
    await flush();
    expect(getNextInboxPage).toHaveBeenCalledWith({
        representedAccountId: 'beate',
        beforeThreadId: 'thread-1',
        beforeNoteId: 'note-1'
    });
    expect(displayedIds(element)).toEqual(['thread-1', 'thread-2', 'note-2']);
});
