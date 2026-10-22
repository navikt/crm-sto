const STORAGE_PREFIX = 'sto-read-messages';
export const READ_STATE_EVENT = 'storeadstatechange';

function storageKey(userId, threadId) {
    return `${STORAGE_PREFIX}-${userId}-${threadId}`;
}

export function getReadMessageIds(userId, threadId) {
    if (!userId || !threadId) return [];
    try {
        const value = localStorage.getItem(storageKey(userId, threadId));
        if (!value) return [];
        const ids = JSON.parse(value);
        if (!Array.isArray(ids) || !ids.every((id) => typeof id === 'string')) {
            throw new TypeError('Invalid STO read receipts');
        }
        return ids;
    } catch (error) {
        console.error('Could not restore local STO read receipts:', error);
        return [];
    }
}

export function markMessagesRead(userId, threadId, messageIds) {
    if (!userId || !threadId || messageIds.length === 0) return;
    const ids = [...new Set([...getReadMessageIds(userId, threadId), ...messageIds])];
    try {
        localStorage.setItem(storageKey(userId, threadId), JSON.stringify(ids));
        window.dispatchEvent(new CustomEvent(READ_STATE_EVENT, { detail: { userId, threadId } }));
    } catch (error) {
        console.error('Could not save local STO read receipts:', error);
    }
}

export function isMessageRead(readIds, messageId, senderContactId, viewerContactId) {
    return Boolean(
        messageId &&
            ((senderContactId && viewerContactId && senderContactId === viewerContactId) || readIds.includes(messageId))
    );
}
