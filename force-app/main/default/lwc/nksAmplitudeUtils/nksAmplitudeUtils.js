export function logAmplitudeEvent(eventName, eventData) {
    const amplitude = window.amplitude;
    setTimeout(() => {
        try {
            if (amplitude) {
                console.log(amplitude);
                amplitude.logEvent(eventName, eventData);
            }
        } catch (error) {
            console.error(error);
        }
    });
}

export function handleClickableElements(department) {
    window.onclick = (event) => {
        let clickable =
            event.target.tagName === 'BUTTON' ||
            event.target.tagName === 'INPUT' ||
            event.target.tagName === 'SPAN' ||
            event.target.tagName === 'FLOWRUNTIME-FLOW' ||
            event.target.tagName === 'FLOWRUNTIME-NAVIGATION-BAR' ||
            event.target.tagName === 'A' ||
            event.target.onclick != null ||
            window.getComputedStyle(event.target).cursor == 'pointer';

        event.target && clickable
            ? logAmplitudeEvent('Test Event', {
                  type: `Clicked element: ${event.target.tagName} ------> Element's text: ${event.target.innerText}`,
                  department: department
              })
            : console.log('no target');
    };
}
