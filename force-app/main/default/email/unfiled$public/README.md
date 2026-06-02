# Email Templates - Application Submission Confirmation

## Problem Fixed
The issue where `{!$Record.Name}` was showing as literal text instead of the actual Application record name has been resolved.

## Available Templates

### 1. Application_Submission_Confirmation (Text)
- **File**: `Application_Submission_Confirmation.email`
- **Type**: Plain text email
- **Use Case**: Basic email notifications

### 2. Application_Submission_Confirmation_HTML (HTML)
- **File**: `Application_Submission_Confirmation_HTML.email`
- **Type**: HTML formatted email
- **Use Case**: Professional-looking emails with styling

## Merge Fields Used

Both templates use proper Salesforce email template merge field syntax:

- `{!Candidate__c.First_Name__c}` - Candidate's first name from the related Candidate record
- `{!Application__c.Name}` - Application record's Name field (auto-number)

## How to Use in Flow

If you're sending this email from a Flow:

1. **Add Send Email Action** to your Flow
2. **Select "Use Email Template"**
3. **Choose** one of these templates:
   - "Application Submission Confirmation" (text)
   - "Application Submission Confirmation (HTML)" (recommended)
4. **Set Related Record ID** to the Application record ID
5. **Set Recipient** to the Candidate's email

### Flow Configuration Example:

```
Action: Send Email
Email Template: Application Submission Confirmation (HTML)
Recipient Email Address: {!Get_Candidate.Email__c}
Related Record ID: {!$Record.Id}
```

## How to Use in Apex

```apex
// Get the email template
EmailTemplate template = [
    SELECT Id, Subject, Body 
    FROM EmailTemplate 
    WHERE DeveloperName = 'Application_Submission_Confirmation_HTML' 
    LIMIT 1
];

// Create email message
Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
email.setTemplateId(template.Id);
email.setTargetObjectId(candidateId); // Contact or User Id
email.setWhatId(applicationId); // Application__c record Id
email.setSaveAsActivity(false);

// Send email
Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
```

## Deployment

To deploy these templates to your org:

```bash
sf project deploy start --metadata EmailTemplate:Application_Submission_Confirmation
sf project deploy start --metadata EmailTemplate:Application_Submission_Confirmation_HTML
```

Or deploy all email templates:

```bash
sf project deploy start --source-dir force-app/main/default/email
```

## Testing

1. Deploy the templates to your org
2. Navigate to Setup > Email Templates
3. Search for "Application Submission Confirmation"
4. Click "Preview" to see how the email will look
5. Use the template in your Flow or Apex code

## Customization

To customize the templates:

1. Edit the `.email` file for the email body
2. Edit the `.email-meta.xml` file for:
   - Subject line
   - Template name
   - Template type (text/html)
3. Deploy changes to your org

## Important Notes

- Email templates in Salesforce use `{!ObjectName.FieldName}` syntax, NOT Flow syntax `{!$Record.FieldName}`
- The `Related Record ID` in Flow must be set to establish the context for merge fields
- For HTML templates, ensure all styling is inline for best email client compatibility
- Always test emails in multiple email clients (Gmail, Outlook, etc.)