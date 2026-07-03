sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/core/routing/History",
    "sap/ui/core/ValueState",
    "sap/m/MessageBox"
], function(Controller, History, ValueState, MessageBox) {
    "use strict";

    return Controller.extend("zewm004.controller.Main", {

        onInit: function() {
            this._values = { s1Material: "", s1SrcLoc: "", s1Batch: "", s1Qty: "", s1PackMat: "" };
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
            if (oControl && oControl.setValue) {
                this._lastInputId = sShortId;
            }
        },

        onMaterialLiveChange: function(oEvent) {
            this._values.s1Material = oEvent.getParameter("value");
        },

        onSrcLocLiveChange: function(oEvent) {
            this._values.s1SrcLoc = oEvent.getParameter("value");
        },

        onBatchLiveChange: function(oEvent) {
            this._values.s1Batch = oEvent.getParameter("value");
        },

        onQtyLiveChange: function(oEvent) {
            this._values.s1Qty = oEvent.getParameter("value");
        },

        onPackMatLiveChange: function(oEvent) {
            this._values.s1PackMat = oEvent.getParameter("value");
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
            switch (sShortId) {
                case "s1Material": this.onMaterialSubmit(sDomValue); break;
                case "s1SrcLoc": this.onSrcLocSubmit(sDomValue); break;
                case "s1Batch": this.onBatchSubmit(sDomValue); break;
                case "s1Qty": this.onQtySubmit(sDomValue); break;
                case "s1PackMat": this.onPackMatSubmit(sDomValue); break;
            }
        },

        onBack: function() {
            var oHistory = History.getInstance();
            var sPreviousHash = oHistory.getPreviousHash();
            if (sPreviousHash !== undefined) {
                window.history.go(-1);
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
            ["s1Material", "s1SrcLoc", "s1Batch", "s1Qty", "s1PackMat"].forEach(function(sId) {
                var oCtrl = this.byId(sId);
                oCtrl.setValue("");
                this._clearError(oCtrl);
            }.bind(this));
            this._values = { s1Material: "", s1SrcLoc: "", s1Batch: "", s1Qty: "", s1PackMat: "" };
            this.byId("s1Material").focus();
        },

        onMaterialSubmit: function(sDomValue) {
            var oInput = this.byId("s1Material");
            var sValue = (sDomValue || this._values.s1Material || oInput.getValue() || "").trim();

            if (!sValue) {
                this._showError(oInput, this._i18n("msgMaterialMandatory"));
                return;
            }
            this._values.s1Material = sValue;
            this._clearError(oInput);

            this._callApi("check_material", { material: sValue }, function() {
                this.byId("s1SrcLoc").focus();
            }.bind(this), function(sMsg) {
                this._showError(oInput, sMsg || this._i18n("msgMaterialNotExist", [sValue]));
            }.bind(this), "ZEWM004-S1-CHECKMAT");
        },

        onSrcLocSubmit: function(sDomValue) {
            var oInput = this.byId("s1SrcLoc");
            var sValue = (sDomValue || this._values.s1SrcLoc || oInput.getValue() || "").trim();

            if (!sValue) {
                this._showError(oInput, this._i18n("msgSrcLocMandatory"));
                return;
            }
            this._values.s1SrcLoc = sValue;
            this._clearError(oInput);

            this._callApi("check_sloc", { material: this._values.s1Material, srcLoc: sValue }, function() {
                this.byId("s1Batch").focus();
            }.bind(this), function(sMsg) {
                this._showError(oInput, sMsg || this._i18n("msgSrcLocNotExist", [sValue]));
            }.bind(this), "ZEWM004-S1-CHECKSLOC");
        },

        onBatchSubmit: function(sDomValue) {
            var oInput = this.byId("s1Batch");
            var sValue = (sDomValue || this._values.s1Batch || oInput.getValue() || "").trim();

            if (!sValue) {
                this._showError(oInput, this._i18n("msgBatchMandatory"));
                return;
            }
            this._values.s1Batch = sValue;
            this._clearError(oInput);

            this._callApi("check_batch", { material: this._values.s1Material, srcLoc: this._values.s1SrcLoc, batch: sValue }, function() {
                this.byId("s1Qty").focus();
            }.bind(this), function(sMsg) {
                this._showError(oInput, sMsg || this._i18n("msgBatchNotExist", [sValue]));
            }.bind(this), "ZEWM004-S1-CHECKBATC");
        },

        onQtySubmit: function(sDomValue) {
            var oInput = this.byId("s1Qty");
            var sValue = (sDomValue || this._values.s1Qty || oInput.getValue() || "").trim();

            if (!sValue) {
                this._showError(oInput, this._i18n("msgQtyMandatory"));
                return;
            }
            this._values.s1Qty = sValue;
            this._clearError(oInput);

            this._callApi("check_qty", {
                material: this._values.s1Material,
                srcLoc: this._values.s1SrcLoc,
                batch: this._values.s1Batch,
                qty: sValue
            }, function() {
                this.byId("s1PackMat").focus();
            }.bind(this), function(sMsg) {
                this._showError(oInput, sMsg || this._i18n("msgQtyInvalid", [sValue]));
            }.bind(this), "ZEWM004-S1-CHECKQTY");
        },

        onPackMatSubmit: function(sDomValue) {
            var oInput = this.byId("s1PackMat");
            var sValue = (sDomValue || this._values.s1PackMat || oInput.getValue() || "").trim();

            if (!sValue) {
                this._showError(oInput, this._i18n("msgPackMatMandatory"));
                return;
            }
            this._values.s1PackMat = sValue;
            this._clearError(oInput);

            this._callApi("check_pack", { packMat: sValue }, function() {
            }, function(sMsg) {
                this._showError(oInput, sMsg || this._i18n("msgPackMatNotExist", [sValue]));
            }.bind(this), "ZEWM004-S1-CHECKPACKMAT");
        },

        onConfirm: function() {
            var mFields = {
                s1Material: this._i18n("msgMaterialMandatory"),
                s1SrcLoc: this._i18n("msgSrcLocMandatory"),
                s1Batch: this._i18n("msgBatchMandatory"),
                s1Qty: this._i18n("msgQtyMandatory"),
                s1PackMat: this._i18n("msgPackMatMandatory")
            };

            for (var sFieldId in mFields) {
                if (!this._values[sFieldId] || !this._values[sFieldId].trim()) {
                    this._showError(this.byId(sFieldId), mFields[sFieldId]);
                    return;
                }
            }

            this._callApi("create_hu", {
                material: this._values.s1Material,
                srcLoc: this._values.s1SrcLoc,
                batch: this._values.s1Batch,
                qty: this._values.s1Qty,
                packMat: this._values.s1PackMat
            }, function(oData) {
                var oResData = {};
                try { oResData = JSON.parse(oData.resdata || "{}"); } catch (e) { oResData = {}; }

                var oFlowModel = this.getOwnerComponent().getModel("flow");
                oFlowModel.setProperty("/hu", oResData.hu || "");
                oFlowModel.setProperty("/recommendedBin", oResData.recommendedBin || "");

                this.onRefresh();
                this.getOwnerComponent().getRouter().navTo("RouteScreen2");
            }.bind(this), function(sMsg) {
                MessageBox.error(sMsg || "Create HU request failed");
            }, "ZEWM004-S1-CREATEHU");
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
