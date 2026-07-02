sap.ui.define([
    "sap/ui/core/UIComponent",
    "sap/ui/model/json/JSONModel",
    "zewm004/model/models"
], (UIComponent, JSONModel, models) => {
    "use strict";

    return UIComponent.extend("zewm004.Component", {
        metadata: {
            manifest: "json",
            interfaces: [
                "sap.ui.core.IAsyncContentCreation"
            ]
        },

        init() {
            // call the base component's init function
            UIComponent.prototype.init.apply(this, arguments);

            // set the device model
            this.setModel(models.createDeviceModel(), "device");

            // shared model to carry the HU created on Screen 1 into Screen 2
            this.setModel(new JSONModel({ hu: "", recommendedBin: "" }), "flow");

            // enable routing
            this.getRouter().initialize();
        }
    });
});