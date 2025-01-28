export const AnalyticsEvents = {
    NAVIGATION: 'navigere',
    ACC_EXPAND: 'accordion åpnet',
    ACC_COLLAPSE: 'accordion lukket',
    MODAL_OPEN: 'modal åpnet',
    MODAL_CLOSE: 'modal lukket',
    FORM_STEP_COMPLETED: 'Skjemassteg fullført',
    FORM_COMPLETED: 'Skjema fullført'
};

export function logAmplitudeEvent(eventName, eventData) {
    const origin = 'crm-innboks';
    const analytics = window.dekoratorenAmplitude;
    if (analytics) {
        analytics({ eventName, origin, eventData });
    }
}

export function changeParameter(key, value) {
    window.postMessage(
        {
            source: 'decoratorClient',
            event: 'params',
            payload: { [key]: value }
        },
        window.location.origin
    );
}

const waitForRetry = async () =>
    // eslint-disable-next-line @lwc/lwc/no-async-operation, @locker/locker/distorted-window-set-timeout
    new Promise((resolve) => setTimeout(resolve, 500));

export async function validateAmplitudeFunction(retries = 5) {
    if (typeof window.dekoratorenAmplitude === 'function') {
        return Promise.resolve(true);
    }

    if (retries === 0) {
        return Promise.resolve(false);
    }

    await waitForRetry();

    return validateAmplitudeFunction(retries - 1);
}

export function logNavigationEvent(data) {
    logAmplitudeEvent(AnalyticsEvents.NAVIGATION, data);
}
