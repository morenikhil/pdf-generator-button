@IsTest
private class PdfGeneratorControllerTest {

    // ─── Test data setup ──────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        Account acc = new Account(Name = 'PDF Test Account');
        insert acc;
    }

    private static Account getTestAccount() {
        return [SELECT Id FROM Account WHERE Name = 'PDF Test Account' LIMIT 1];
    }

    // ─── generateAndSavePdf ───────────────────────────────────────────────────

    @IsTest
    static void testGeneratePdf_Success() {
        Account acc = getTestAccount();

        Test.startTest();
        Id cvId = PdfGeneratorController.generateAndSavePdf(
            acc.Id,
            'Account',
            'RecordPdfPage',
            'TestAccount_PDF.pdf'
        );
        Test.stopTest();

        System.assertNotEquals(null, cvId, 'ContentVersion Id should be returned.');

        ContentVersion cv = [
            SELECT Id, Title, FileExtension, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cvId
            LIMIT 1
        ];
        System.assertEquals('pdf', cv.FileExtension.toLowerCase(), 'File extension must be pdf.');

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :acc.Id
              AND ContentDocumentId = :cv.ContentDocumentId
        ];
        System.assertEquals(1, links.size(), 'ContentDocumentLink should link PDF to the record.');
    }

    @IsTest
    static void testGeneratePdf_AutoFileName() {
        Account acc = getTestAccount();

        Test.startTest();
        Id cvId = PdfGeneratorController.generateAndSavePdf(
            acc.Id, 'Account', 'RecordPdfPage', null
        );
        Test.stopTest();

        System.assertNotEquals(null, cvId, 'Should succeed with auto-generated file name.');
        ContentVersion cv = [SELECT Title FROM ContentVersion WHERE Id = :cvId LIMIT 1];
        System.assert(cv.Title.startsWith('Account_'), 'Auto-name should start with objectApiName.');
    }

    @IsTest
    static void testGeneratePdf_AppendsPdfExtension() {
        Account acc = getTestAccount();

        Test.startTest();
        Id cvId = PdfGeneratorController.generateAndSavePdf(
            acc.Id, 'Account', 'RecordPdfPage', 'NoExtensionFile'
        );
        Test.stopTest();

        ContentVersion cv = [SELECT PathOnClient FROM ContentVersion WHERE Id = :cvId LIMIT 1];
        System.assert(
            cv.PathOnClient.endsWithIgnoreCase('.pdf'),
            '.pdf extension should be appended automatically.'
        );
    }

    @IsTest
    static void testGeneratePdf_BlankRecordId_ThrowsException() {
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            PdfGeneratorController.generateAndSavePdf(null, 'Account', 'RecordPdfPage', 'test.pdf');
            Test.stopTest();
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'AuraHandledException expected for blank recordId.');
    }

    @IsTest
    static void testGeneratePdf_BlankVfPageName_ThrowsException() {
        Account acc = getTestAccount();
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            PdfGeneratorController.generateAndSavePdf(acc.Id, 'Account', '', 'test.pdf');
            Test.stopTest();
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        System.assert(exceptionThrown, 'AuraHandledException expected for blank vfPageName.');
    }

    // ─── getGeneratedPdfs ─────────────────────────────────────────────────────

    @IsTest
    static void testGetGeneratedPdfs_ReturnsPdfs() {
        Account acc = getTestAccount();

        // Insert a ContentVersion and link it
        ContentVersion cv = new ContentVersion(
            Title         = 'ExistingPDF',
            PathOnClient  = 'ExistingPDF.pdf',
            VersionData   = Blob.valueOf('dummy'),
            IsMajorVersion = true
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId    = acc.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        insert cdl;

        Test.startTest();
        List<ContentVersion> results = PdfGeneratorController.getGeneratedPdfs(acc.Id);
        Test.stopTest();

        System.assertNotEquals(0, results.size(), 'Should return at least one PDF.');
    }

    @IsTest
    static void testGetGeneratedPdfs_BlankRecordId_ReturnsEmpty() {
        Test.startTest();
        List<ContentVersion> results = PdfGeneratorController.getGeneratedPdfs(null);
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Blank recordId should return empty list.');
    }

    @IsTest
    static void testGetGeneratedPdfs_NoFiles_ReturnsEmpty() {
        Account acc = getTestAccount();
        Test.startTest();
        List<ContentVersion> results = PdfGeneratorController.getGeneratedPdfs(acc.Id);
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Record with no PDFs should return empty list.');
    }
}
