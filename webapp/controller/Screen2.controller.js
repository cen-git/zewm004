sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/core/routing/History",
    "sap/ui/core/ValueState",
    "sap/m/MessageBox"
], function(Controller, History, ValueState, MessageBox) {
    "use strict";

    return Controller.extend("zewm004.controller.Screen2", {

        onInit: function() {
            this._values = { s2DestBin: "" };
            this._lastInputId = "";
            this._focusHandler = this._onFocus.bind(this);
            document.addEventListener("focusin", this._focusHandler);
            this._keyHandler = this._onKeyDown.bind(this);
            document.addEventListener("keydown", this._keyHandler);
        },

        onExit: function() {
            document.removeEventListener("focusin", this._focusHandler);
            document.removeEventListener("keydown", this._keyHandler);
        },

        _onFocus: function(oEvent) {
            var sShortId = oEvent.target.id.replace(/-inner$/, "").split("--").pop();
            var oControl = this.getView().byId(sShortId);
            if (oControl && oControl.setValue && sShortId === "s2DestBin") {
                this._lastInputId = sShortId;
            }
        },

        onDestBinLiveChange: function(oEvent) {
            this._values.s2DestBin = oEvent.getParameter("value");
        },

        _onKeyDown: function(oEvent) {
            if (oEvent.key === "Enter") {
                this._onEnter();
                return;
            }
            switch (oEvent.key) {
                case "F2": oEvent.preventDefault(); this.onClear(); break;
                case "F3": oEvent.preventDefault(); this.onRefresh(); break;
                case "F7": oEvent.preventDefault(); this.onBack(); break;
                case "F9": oEvent.preventDefault(); this.onConfirm(); break;
            }
        },

        _onEnter: function() {
            var oActive = document.activeElement;
            if (!oActive) { return; }
            var sDomValue = oActive.value || "";
            var sShortId = oActive.id.replace(/-inner$/, "").split("--").pop();
            if (sShortId === "s2DestBin") {
                this.onDestBinSubmit(sDomValue);
            }
        },

        onBack: function() {
            var oHistory = History.getInstance();
            var sPreviousHash = oHistory.getPreviousHash();
            if (sPreviousHash !== undefined) {
                window.history.go(-1);
            } else {
                this.getOwnerComponent().getRouter().navTo("RouteMain");
            }
        },

        onClear: function() {
            var sShortId = this._lastInputId;
            if (!sShortId) { return; }
            var oControl = this.getView().byId(sShortId);
            if (oControl && oControl.setValue) {
                oControl.setValue("");
                this._values[sShortId] = "";
                this._clearError(oControl);
            }
        },

        onRefresh: function() {
            var oCtrl = this.byId("s2DestBin");
            oCtrl.setValue("");
            this._clearError(oCtrl);
            this._values.s2DestBin = "";
            oCtrl.focus();
        },

        onDestBinSubmit: function(sDomValue) {
            var oInput = this.byId("s2DestBin");
            var sValue = (sDomValue || this._values.s2DestBin || oInput.getValue() || "").trim();

            if (!sValue) {
                this._showError(oInput, this._i18n("msgDestBinMandatory"));
                return;
            }
            this._values.s2DestBin = sValue;
            this._clearError(oInput);

            var sHU = this.getOwnerComponent().getModel("flow").getProperty("/hu");
            this._callApi("check_bin", { hu: sHU, destBin: sValue }, function() {
            }, function(sMsg) {
                this._showError(oInput, sMsg || this._i18n("msgDestBinInvalid", [sValue]));
            }.bind(this), "ZEWM004-S2-CHECKBIN");
        },

        onConfirm: function() {
            var oInput = this.byId("s2DestBin");
            var sDestBin = (this._values.s2DestBin || oInput.getValue() || "").trim();

            if (!sDestBin) {
                this._showError(oInput, this._i18n("msgDestBinMandatory"));
                return;
            }

            var oFlowModel = this.getOwnerComponent().getModel("flow");
            var sHU = oFlowModel.getProperty("/hu");

            this._callApi("transfer", { hu: sHU, destBin: sDestBin }, function(oData) {
                MessageBox.success(oData.resmsg || this._i18n("msgTransferSuccess"));
                this.onRefresh();
            }.bind(this), function(sMsg) {
                MessageBox.error(sMsg || "Transfer request failed");
            }, "ZEWM004-S2-TRANSFER");
        },

        _callApi: function(sMname, oParams, fnSuccess, fnError, sCode) {
            var oModel = this.getOwnerComponent().getModel();
            if (!oModel) { fnError("OData model not available"); return; }
            if (oModel.isMetadataLoadingFailed && oModel.isMetadataLoadingFailed()) {
                fnError("Metadata loading failed - check OData service: /sap/opu/odata/sap/ZZAPI_UI_ODATA/"); return;
            }
            var oEntry = {
                uuid: this._generateUuid(),
                code: sCode || "ZEWM004",
                reqparam: JSON.stringify(Object.assign(
                    { fname: "ZCL_ZEWM004_TRANSFER", mname: sMname.toUpperCase() },
                    oParams
                ))
            };
            oModel.create("/OData", oEntry, {
                success: function(oData) {
                    if (oData.restype === "E") { fnError(oData.resmsg); }
                    else { fnSuccess(oData); }
                },
                error: function(oError) {
                    var sMsg = "";
                    try { sMsg = JSON.parse(oError.responseText).error.message.value; }
                    catch (e) { sMsg = oError.message || oError.statusText || e.message || ""; }
                    fnError(sMsg);
                }
            });
        },

        _showError: function(oInput, sMessage) {
            oInput.setValueState(ValueState.Error);
            oInput.setValueStateText(sMessage);
            oInput.focus();
        },

        _clearError: function(oInput) {
            oInput.setValueState(ValueState.None);
            oInput.setValueStateText("");
        },

        _i18n: function(sKey, aArgs) {
            return this.getView().getModel("i18n").getResourceBundle().getText(sKey, aArgs);
        },

        _generateUuid: function() {
            return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function(c) {
                var r = Math.random() * 16 | 0;
                return (c === "x" ? r : (r & 0x3 | 0x8)).toString(16);
            });
        }
    });
});
