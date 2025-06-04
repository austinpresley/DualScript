/*  Simple Stream Deck PI script:
    ‑ populates the two textareas from saved settings
    ‑ saves on every keystroke                                      */

let websocket, uuid;

/* Called automatically by Stream Deck on load */
function connectElgatoStreamDeckSocket (inPort, inUUID, inRegisterEvent, inInfo, inActionInfo) {

    uuid = inUUID;
    const actionInfo = JSON.parse(inActionInfo);
    const saved     = actionInfo.payload.settings || {};

    /* open WS back to the Stream Deck app */
    websocket = new WebSocket('ws://localhost:' + inPort);

    websocket.onopen = () => {
        websocket.send(JSON.stringify({ event: inRegisterEvent, uuid }));

        /* fill the two fields from saved settings */
        document.getElementById('scriptDown').value = saved.scriptDown || '';
        document.getElementById('scriptUp').value   = saved.scriptUp   || '';
    };

    /* save whenever the user types */
    ['scriptDown', 'scriptUp'].forEach(id => {
        document.getElementById(id).addEventListener('input', () => {
            const payload = {
                scriptDown: document.getElementById('scriptDown').value,
                scriptUp:   document.getElementById('scriptUp').value
            };
            websocket.send(JSON.stringify({
                event:   'setSettings',
                context: uuid,
                payload
            }));
        });
    });
}