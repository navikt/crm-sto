import markThreadRead from '@salesforce/apex/stoThreadReadState.markThreadRead';

export const READ_STATE_EVENT = 'storeadstatechange';

export function latestDisplayedMessage(groups) {
    return groups
        .flatMap((group) => (group.groupMessages || []).map((entry) => entry.message))
        .filter((message) => message.CRM_Type__c === 'Message' || message.CRM_Type__c === 'Info')
        .sort((first, second) => {
            const dateDifference = new Date(second.CreatedDate).getTime() - new Date(first.CreatedDate).getTime();
            if (dateDifference) return dateDifference;
            return first.Id < second.Id ? 1 : first.Id > second.Id ? -1 : 0;
        })[0];
}

export async function markMessagesRead(threadId, latestDisplayedMessageId) {
    const params = { threadId, latestDisplayedMessageId };
    try {
        await markThreadRead(params);
    } catch (error) {
        const errors = [error.body, ...(error.body?.pageErrors || [])].filter(Boolean);
        const retryable = errors.some(
            (entry) =>
                entry.statusCode === 'DUPLICATE_VALUE' ||
                entry.statusCode === 'UNABLE_TO_LOCK_ROW' ||
                /DUPLICATE_VALUE|UNABLE_TO_LOCK_ROW/.test(entry.message || '')
        );
        if (!retryable) throw error;
        await markThreadRead(params);
    }
    window.dispatchEvent(new CustomEvent(READ_STATE_EVENT, { detail: { threadId } }));
}
