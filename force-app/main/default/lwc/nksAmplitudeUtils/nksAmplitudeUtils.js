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

export function handleClickableElements(department) {
    window.onclick = (event) => {
        let clickable =
            event.target.tagName === 'BUTTON' ||
            event.target.tagName === 'A' ||
            event.target.onclick != null ||
            window.getComputedStyle(event.target).cursor == 'pointer';

        event.target && clickable && event.target.innerText
            ? logAmplitudeEvent('Test Event', {
                  type: `Click ${event.target.innerText} tab`,
                  department: department
              })
            : /*
            console.log(
                  JSON.stringify({
                      element: event.target,
                      tagName: event.target.tagName,
                      text: event.target.textContent.trim().replace(/\s{2,}/g, ' ')
                      innerHTML: event.target.innerHTML,
                      innerText: event.target.innerText
                  })
              )*/
              console.log('no target');
    };
}

// does not work for SF ):
export function getAllClickableElementsOnAPage() {
    window.scrollTo(0, 0);
    var bodyRect = document.body.getBoundingClientRect();

    var items = Array.prototype.slice
        .call(document.querySelectorAll('*'))
        .map(function (element) {
            var rect = element.getBoundingClientRect();
            return {
                element: element,
                include:
                    element.tagName === 'BUTTON' ||
                    element.tagName === 'A' ||
                    element.onclick != null ||
                    window.getComputedStyle(element).cursor == 'pointer',
                rect: {
                    left: Math.max(rect.left - bodyRect.x, 0),
                    top: Math.max(rect.top - bodyRect.y, 0),
                    right: Math.min(rect.right - bodyRect.x, document.body.clientWidth),
                    bottom: Math.min(rect.bottom - bodyRect.y, document.body.clientHeight)
                },
                text: element.textContent.trim().replace(/\s{2,}/g, ' '),
                innerText: element.innerHTML
            };
        })
        .filter(
            (item) => item.include && (item.rect.right - item.rect.left) * (item.rect.bottom - item.rect.top) >= 20
        );

    // Only keep inner clickable items
    items = items.filter((x) => !items.some((y) => x.element.contains(y.element) && x !== y));
    console.log('items:\n');
    items.forEach((item) => {
        console.log(item.innerText, '\n');
    });
}
