import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import generateAndSavePdf from '@salesforce/apex/PdfGeneratorController.generateAndSavePdf';
import getGeneratedPdfs from '@salesforce/apex/PdfGeneratorController.getGeneratedPdfs';

const KB = 1024;
const MB = KB * 1024;

export default class PdfGeneratorButton extends NavigationMixin(LightningElement) {
    /** Record Id injected by the Lightning record page. */
    @api recordId;

    /** Object API name injected by the Lightning record page. */
    @api objectApiName;

    /** Customisable label shown on the generate button (Design Attribute). */
    @api buttonLabel = 'Generate PDF';

    /**
     * API name of the Visualforce page used to render the PDF.
     * Override to point at an object-specific VF page. (Design Attribute)
     */
    @api vfPageName = 'RecordPdfPage';

    /**
     * Optional static file name. When blank the name is auto-built from
     * objectApiName + recordId + today's date. (Design Attribute)
     */
    @api pdfFileName;

    @track isLoading = false;
    @track pdfList = [];

    _wiredPdfsResult;

    // ─── Wired data ───────────────────────────────────────────────────────────

    @wire(getGeneratedPdfs, { recordId: '$recordId' })
    wiredPdfs(result) {
        this._wiredPdfsResult = result;
        if (result.data) {
            this.pdfList = result.data.map(cv => ({
                ...cv,
                formattedSize: this._formatBytes(cv.ContentSize)
            }));
        } else if (result.error) {
            this._showToast('Error loading PDFs', this._extractMessage(result.error), 'error');
        }
    }

    // ─── Getters ──────────────────────────────────────────────────────────────

    get isDisabled() {
        return this.isLoading;
    }

    get hasPdfs() {
        return this.pdfList && this.pdfList.length > 0;
    }

    get hasNoPdfs() {
        return !this.isLoading && (!this.pdfList || this.pdfList.length === 0);
    }

    get _computedFileName() {
        if (this.pdfFileName) return this.pdfFileName;
        const today = new Date().toISOString().slice(0, 10);
        return `${this.objectApiName}_${this.recordId}_${today}.pdf`;
    }

    // ─── Event handlers ───────────────────────────────────────────────────────

    handleGeneratePdf() {
        this.isLoading = true;

        generateAndSavePdf({
            recordId: this.recordId,
            objectApiName: this.objectApiName,
            vfPageName: this.vfPageName,
            fileName: this._computedFileName
        })
            .then(contentVersionId => {
                this._showToast('PDF Generated', 'The PDF has been saved to Files.', 'success');
                this.dispatchEvent(
                    new CustomEvent('pdfgenerated', {
                        detail: { contentVersionId, recordId: this.recordId },
                        bubbles: true,
                        composed: true
                    })
                );
                return refreshApex(this._wiredPdfsResult);
            })
            .catch(error => {
                this._showToast('Error Generating PDF', this._extractMessage(error), 'error', 'sticky');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleDownload(event) {
        const contentDocumentId = event.currentTarget.dataset.docId;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: {
                selectedRecordId: contentDocumentId
            }
        });
    }

    handleRefresh() {
        refreshApex(this._wiredPdfsResult);
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    _showToast(title, message, variant, mode = 'dismissable') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }

    _extractMessage(error) {
        if (!error) return 'An unknown error occurred.';
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }

    _formatBytes(bytes) {
        if (!bytes || bytes === 0) return '0 B';
        if (bytes >= MB) return (bytes / MB).toFixed(1) + ' MB';
        if (bytes >= KB) return (bytes / KB).toFixed(1) + ' KB';
        return bytes + ' B';
    }
}
