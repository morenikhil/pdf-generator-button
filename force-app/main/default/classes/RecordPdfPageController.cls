/**
 * Controller for the generic RecordPdfPage Visualforce template.
 *
 * Reads URL params:  ?id=<recordId>&objectApiName=<SObjectType>
 * Builds a list of FieldRow (label + value) via dynamic SOQL using
 * Schema.DescribeSObjectResult so the same page works for any object.
 */
public without sharing class RecordPdfPageController {

    public String  recordId      { get; private set; }
    public String  objectApiName { get; private set; }
    public String  recordLabel   { get; private set; }
    public String  generatedDate { get; private set; }
    public List<FieldRow> fieldRows { get; private set; }

    // Fields rendered for every object (extend as needed)
    private static final List<String> COMMON_FIELDS = new List<String>{
        'Name', 'CreatedDate', 'LastModifiedDate', 'OwnerId', 'Description'
    };

    public class FieldRow {
        public String label { get; set; }
        public String value { get; set; }
        public FieldRow(String label, String value) {
            this.label = label;
            this.value = value == null ? '' : value;
        }
    }

    public RecordPdfPageController() {
        recordId      = ApexPages.currentPage().getParameters().get('id');
        objectApiName = ApexPages.currentPage().getParameters().get('objectApiName');
        generatedDate = Datetime.now().format('MMMM d, yyyy h:mm a');
        fieldRows     = new List<FieldRow>();

        if (String.isBlank(recordId) || String.isBlank(objectApiName)) {
            recordLabel = 'Invalid Parameters';
            return;
        }

        loadRecord();
    }

    private void loadRecord() {
        try {
            Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectApiName);
            if (sObjType == null) {
                recordLabel = 'Unknown Object: ' + objectApiName;
                return;
            }

            Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();

            // Build the list of queryable fields present on this object
            List<String> queryFields = new List<String>{ 'Id' };
            for (String fieldName : COMMON_FIELDS) {
                if (fieldMap.containsKey(fieldName.toLowerCase())) {
                    queryFields.add(fieldName);
                }
            }

            String soql = 'SELECT ' + String.join(queryFields, ', ')
                        + ' FROM ' + objectApiName
                        + ' WHERE Id = :recordId LIMIT 1';

            List<SObject> records = Database.query(soql);
            if (records.isEmpty()) {
                recordLabel = 'Record not found';
                return;
            }

            SObject record = records[0];
            recordLabel = (String) record.get('Name') != null
                ? (String) record.get('Name')
                : recordId;

            for (String fieldName : queryFields) {
                if (fieldName == 'Id') continue;
                Schema.DescribeFieldResult dfr = fieldMap.get(fieldName.toLowerCase()).getDescribe();
                Object rawVal = record.get(fieldName);
                fieldRows.add(new FieldRow(dfr.getLabel(), formatValue(rawVal, dfr.getType())));
            }

        } catch (Exception ex) {
            recordLabel = 'Error loading record';
            fieldRows.add(new FieldRow('Error', ex.getMessage()));
        }
    }

    private static String formatValue(Object val, Schema.DisplayType dtype) {
        if (val == null) return '';
        if (dtype == Schema.DisplayType.DATE) {
            return ((Date) val).format();
        }
        if (dtype == Schema.DisplayType.DATETIME) {
            return ((Datetime) val).format('MMMM d, yyyy h:mm a');
        }
        if (dtype == Schema.DisplayType.BOOLEAN) {
            return ((Boolean) val) ? 'Yes' : 'No';
        }
        return String.valueOf(val);
    }
}
