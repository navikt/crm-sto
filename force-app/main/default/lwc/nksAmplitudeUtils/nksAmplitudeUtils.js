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

export function handleClick() {
    document.addEventListener('click', (event) => {
        event.currentTarget
            ? console.log('current target: ', event.currentTarget.innerText)
            : console.log('no current target');
    });
}

export function handleClickableElements(appName, recordId, department) {
    window.onclick = (event) => {
        console.log('tagname: ', JSON.stringify(event.target.tagName));

        let clickable =
            event.target.tagName === 'BUTTON' ||
            event.target.tagName === 'INPUT' ||
            event.target.tagName === 'SPAN' ||
            event.target.tagName === 'FLOWRUNTIME-FLOW' ||
            event.target.tagName === 'FLOWRUNTIME-NAVIGATION-BAR' ||
            event.target.tagName === 'A' ||
            event.target.onclick != null ||
            window.getComputedStyle(event.target).cursor == 'pointer';
        console.log('clickable: ', clickable);
        if (clickable) {
            console.log('innertext: ', event.target.innerText);
        }

        event.target && clickable
            ? logAmplitudeEvent('Test Event', {
                  appName: appName,
                  type: `Clicked element: ${event.target.tagName} ------> Element's text: ${event.target.innerText}`,
                  department: department
              })
            : console.log('no target');
    };
}
