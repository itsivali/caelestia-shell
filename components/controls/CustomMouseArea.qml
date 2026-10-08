import QtQuick

MouseArea {
    id: root

    // Fingers on a trackpad produce a high-resolution pixel delta; a mouse wheel
    // produces an angle delta where one notch is 120 units. Each surface below
    // wants discrete steps, so we accumulate until a whole step has been
    // travelled and keep the remainder - nothing is thrown away any more.
    property int smoothStepPx: 50 // finger pixels per step (continuous input)
    property int angleStep: 120 // angle units per step (one wheel notch)

    property real scrollAccumulated: 0
    property int maxStepsPerEvent: 3

    // Overridden by consumers; called once per accumulated step.
    function onWheel(event: WheelEvent): void {
    }

    onWheel: event => {
        const pixel = event.pixelDelta.y;
        const angle = event.angleDelta.y;

        // ScrollBegin marks the start of a fresh gesture - drop any stale remainder.
        if (event.phase === Qt.ScrollBegin)
            scrollAccumulated = 0;

        // Continuous input only counts as such when the compositor reported it as a
        // gesture; an ordinary wheel reports Qt.NoScrollPhase.
        const smooth = pixel !== 0 && event.phase !== Qt.NoScrollPhase;
        const delta = smooth ? pixel : angle;
        const step = smooth ? smoothStepPx : angleStep;

        if (delta === 0)
            return;

        if (Math.sign(delta) !== Math.sign(scrollAccumulated))
            scrollAccumulated = 0;

        scrollAccumulated += delta;

        let steps = 0;
        while (Math.abs(scrollAccumulated) >= step && steps < maxStepsPerEvent) {
            scrollAccumulated -= Math.sign(scrollAccumulated) * step;
            steps++;
            onWheel(event);
        }
    }
}
