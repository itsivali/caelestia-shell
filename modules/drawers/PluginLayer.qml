pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Renders the enabled plugins for one screen. Every ContentWindow owns a layer,
// so a plugin gets one instance per screen. Plugins are display only: they sit
// in the window's content but outside its input mask, so they never intercept
// clicks.
Item {
    id: root

    function reload(): void {
        for (const child of [...root.children])
            child.destroy();

        for (const file of Plugins.enabledFiles) {
            if (!Plugins.files.includes(file))
                continue;

            let comp = null;
            try {
                comp = Qt.createComponent(Qt.resolvedUrl(file), Component.PreferSynchronous);
            } catch (e) {
                Plugins.reportError(file, e.toString());
                continue;
            }

            if (comp.status !== Component.Ready) {
                console.warn("[plugins] failed to compile", file, comp.errorString());
                Plugins.reportError(file, comp.errorString() || "Failed to compile");
                comp.destroy();
                continue;
            }

            let holder = null;
            let obj = null;
            try {
                holder = holderComp.createObject(root);
                obj = comp.createObject(holder, {});
            } catch (e) {
                Plugins.reportError(file, e.toString());
            }
            comp.destroy();

            if (!holder || !obj) {
                console.warn("[plugins] failed to instantiate", file);
                Plugins.reportError(file, "Could not create the plugin's root object");
                holder?.destroy();
                continue;
            }

            if (!(obj instanceof Item)) {
                console.warn("[plugins] root object is not an Item", file);
                Plugins.reportError(file, "The plugin's root object must be an Item");
                obj.destroy();
                holder.destroy();
                continue;
            }

            // Give plugins with no size of their own the full layer. Note that
            // anchors.top/bottom/left/right hand back an AnchorLine even when
            // unset, so only anchors.fill can be tested for "is it used?".
            const a = obj.anchors;
            if (obj.width === 0 && obj.height === 0 && !a.fill)
                a.fill = holder;

            Plugins.reportError(file, "");
        }
    }

    Component {
        id: holderComp

        Item {
            anchors.fill: parent
        }
    }

    Connections {
        target: Plugins

        function onEnabledFilesChanged(): void {
            root.reload();
        }

        function onFilesChanged(): void {
            root.reload();
        }
    }

    Component.onCompleted: reload()
}
