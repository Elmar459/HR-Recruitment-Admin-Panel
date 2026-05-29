# Email Template Usage Guide

## ✅ Successfully Deployed Template

**Template Name:** Application Submission Confirmation  
**Type:** Text Email Template  
**Status:** ✅ Deployed to your org

## The Fix

The issue where `{!$Record.Name}` was showing as literal text has been **FIXED**. 

### What Changed:
- **Before (Flow syntax):** `{!$Record.Name}` ❌ (shows as text)
- **After (Email template syntax):** `{!Application__c.Name}` ✅ (shows actual value)

## How to Use This Template

### Option 1: Use in Salesforce Flow (Recommended)

1. **Open your Flow** in Flow Builder
2. **Find your Send Email action** (or add a new one)
3. **Configure the action:**
   - Click on the Send Email action
   - Under "Email Template", select **"Use Email Template"**
   - Click the dropdown and search for: **"Application Submission Confirmation"**
   - Select the template
4. **Set the Recipient:**
   - Recipient Email Address: `{!Get_Candidate.Email__c}` (or your variable)
5. **CRITICAL: Set the Related Record ID:**
   - Related Record ID: `{!$Record.Id}` (your Application__c record ID)
   - This is what makes the merge fields work!
6. **Save and Activate** your Flow

### Option 2: Use in Apex Code

```apex
// Get the template
EmailTemplate template = [
    SELECT Id, DeveloperName 
    FROM EmailTemplate 
    WHERE DeveloperName = 'Application_Submission_Confirmation' 
    LIMIT 1
];

// Create the email
Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
email.setTemplateId(template.Id);
email.setTargetObjectId(candidateContactId); // Must be a Contact or User ID
email.setWhatId(applicationRecordId); // Your Application__c record ID
email.setSaveAsActivity(false);

// Send it
Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
```

## Testing the Template

### In Salesforce UI:

1. Go to **Setup** → Search for **"Classic Email Templates"**
2. In the folder list, find **"Unfiled Public Email Templates"**
3. Click on **"Application Submission Confirmation"**
4. Click **"Preview"** button
5. Select an Application record to preview with
6. You should see the actual Application Name instead of `{!$Record.Name}`

### Send a Test Email:

1. Navigate to any Application record
2. Click **Send Email** button (if available)
3. Choose **Use Template**
4. Select **"Application Submission Confirmation"**
5. Send the test email
6. Check that the email shows the actual Application Number

## Merge Fields Available in This Template

| Merge Field | Description | Example Output |
|------------|-------------|----------------|
| `{!Candidate__c.First_Name__c}` | Candidate's first name | "John" |
| `{!Application__c.Name}` | Application auto-number | "APP-0001234" |

## Troubleshooting

### If merge fields still show as text:

1. **Check Related Record ID is set** in your Flow's Send Email action
2. **Verify the field names** match your actual field API names:
   - Is it `First_Name__c` or `FirstName__c`?
   - Check in Setup → Object Manager → Candidate → Fields
3. **Check the relationship** from Application to Candidate
   - The merge field assumes a lookup field named `Candidate__c`
   - If your field name is different, update the template

### If the template doesn't appear:

1. **Refresh your Flow Builder** or Salesforce page
2. **Check the folder**: It's in "Unfiled Public Email Templates"
3. **Verify deployment**: Run `sf project deploy start --metadata EmailTemplate:unfiled$public/Application_Submission_Confirmation`

## Email Content

The template will send:

```
Dear [Candidate First Name],

Thank you for applying to ABB Tech Academy.

Your application has been successfully submitted and is currently under review by our recruitment team.

Application Number: [Actual Application Number - e.g., APP-0001234]

Current Status: New

Expected Review Timeline: 3–5 business days

We appreciate your interest in joining our company.

Best regards,
TechHire Recruitment Team
```

## Next Steps

1. ✅ Template is deployed
2. 🔄 Update your Flow to use this template
3. 🔄 Set the "Related Record ID" to `{!$Record.Id}`
4. ✅ Test with a real Application record
5. ✅ Verify the email shows the actual Application Number

---

**Need to customize the template?**
- Edit: `force-app/main/default/email/unfiled$public/Application_Submission_Confirmation.email`
- Deploy: `sf project deploy start --metadata EmailTemplate:unfiled$public/Application_Submission_Confirmation`