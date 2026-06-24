/**
 * Controller for the pdfGeneratorButton LWC.
 *
 * Responsibilities:
 *  1. Accept a record Id + VF page name from the LWC.
 *  2. Render the VF page as a PDF blob (getContentAsPDF).
 *  3. Persist the blob as a ContentVersion (Salesforce Files).
 *  4. Link the ContentDocument to the source record via ContentDocumentLink.
 *  5. Return existing PDF files already linked to the record.
 */
public with sharing class PdfGeneratorController {

    // ─── Generate & Save ─────────────────────────────────────────────────────

    /**
     * Generates a PDF from the named Visualforce page and saves it as a
     * Salesforce File (ContentVersion) linked to the record.
     *
     * @param recordId       18-char Salesforce record Id.
     * @param objectApiName  API name of the SObject (used for auto file naming).
     * @param vfPageName     API name of the VF page (without /apex/ prefix).
     * @param fileName       Desired file name including .pdf extension.
     * @return               Id of the newly created ContentVersion.
     */
    @AuraEnabled
    public static Id generateAndSavePdf(
        String recordId,
        String objectApiName,
        String vfPageName,
        String fileName
    ) {
        validateInputs(recordId, vfPageName);

        if (String.isBlank(fileName)) {
            fileName = buildFileName(objectApiName, recordId);
        }
        if (!fileName.endsWithIgnoreCase('.pdf')) {
            fileName += '.pdf';
        }

        try {
            Blob pdfBlob = renderPageAsBlob(vfPageName, recordId, objectApiName);

            ContentVersion cv = createContentVersion(fileName, pdfBlob);
            insert cv;

            // Re-query to get the auto-assigned ContentDocumentId
            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

            linkDocumentToRecord(cv.ContentDocumentId, recordId);

            return cv.Id;

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            throw new AuraHandledException('PDF generation failed: ' + ex.getMessage());
        }
    }

    // ─── List existing PDFs ───────────────────────────────────────────────────

    /**
     * Returns the 20 most-recent PDF ContentVersions linked to the record.
     *
     * @param recordId  18-char Salesforce record Id.
     * @return          List of ContentVersion records (Id, Title, ContentSize,
     *                  ContentDocumentId, CreatedDate).
     */
    @AuraEnabled(cacheable=true)
    public static List<ContentVersion> getGeneratedPdfs(String recordId) {
        if (String.isBlank(recordId)) {
            return new List<ContentVersion>();
        }

        try {
            Set<Id> docIds = getLinkedDocumentIds(recordId);
            if (docIds.isEmpty()) {
                return new List<ContentVersion>();
            }

            return [
                SELECT Id, Title, ContentSize, ContentDocumentId, CreatedDate, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                  AND FileExtension = 'pdf'
                  AND IsLatest = true
                ORDER BY CreatedDate DESC
                LIMIT 20
            ];

        } catch (Exception ex) {
            throw new AuraHandledException('Error loading PDF list: ' + ex.getMessage());
        }
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    private static void validateInputs(String recordId, String vfPageName) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('recordId is required.');
        }
        if (String.isBlank(vfPageName)) {
            throw new AuraHandledException('vfPageName is required.');
        }
    }

    private static String buildFileName(String objectApiName, String recordId) {
        String objPart = String.isBlank(objectApiName) ? 'Record' : objectApiName;
        String datePart = String.valueOf(Date.today()).replace('-', '');
        return objPart + '_' + recordId + '_' + datePart;
    }

    private static Blob renderPageAsBlob(String vfPageName, String recordId, String objectApiName) {
        // Test context cannot call getContentAsPDF — return a placeholder blob.
        if (Test.isRunningTest()) {
            return Blob.valueOf('PDF_PLACEHOLDER');
        }

        PageReference pdfPage = new PageReference('/apex/' + vfPageName);
        pdfPage.getParameters().put('id', recordId);
        if (String.isNotBlank(objectApiName)) {
            pdfPage.getParameters().put('objectApiName', objectApiName);
        }
        return pdfPage.getContentAsPDF();
    }

    private static ContentVersion createContentVersion(String fileName, Blob pdfBlob) {
        ContentVersion cv       = new ContentVersion();
        cv.Title                = fileName.removeEndIgnoreCase('.pdf');
        cv.PathOnClient         = fileName;
        cv.VersionData          = pdfBlob;
        cv.IsMajorVersion       = true;
        cv.Origin               = 'H'; // Content originated from this org
        return cv;
    }

    private static void linkDocumentToRecord(Id contentDocumentId, String recordId) {
        ContentDocumentLink cdl  = new ContentDocumentLink();
        cdl.ContentDocumentId    = contentDocumentId;
        cdl.LinkedEntityId       = recordId;
        cdl.ShareType            = 'V';        // Viewer permission
        cdl.Visibility           = 'AllUsers';
        insert cdl;
    }

    private static Set<Id> getLinkedDocumentIds(String recordId) {
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        return docIds;
    }
}
