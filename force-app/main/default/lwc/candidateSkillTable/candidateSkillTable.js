import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getCandidateSkills from '@salesforce/apex/CandidateSkillController.getCandidateSkills';

const COLUMNS = [
    {
        label: 'Skill',
        fieldName: 'skillName',
        type: 'text',
        initialWidth: 200
    },
    {
        label: 'Candidate Skill',
        fieldName: 'recordUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'recordName' },
            target: '_blank'
        },
        initialWidth: 150
    },
    {
        label: 'Proficiency Level',
        fieldName: 'proficiencyLevel',
        type: 'text',
        initialWidth: 130
    },
    {
        label: 'Years of Experience',
        fieldName: 'hasExperience',
        type: 'boolean',
        typeAttributes: { textLabel: { fieldName: 'hasExperienceLabel' } },
        initialWidth: 150
    },
    {
        label: 'Is Verified',
        fieldName: 'isVerified',
        type: 'boolean',
        initialWidth: 100
    },
    {
        label: 'Verified By',
        fieldName: 'verifiedByName',
        type: 'text',
        initialWidth: 150
    }
];

export default class CandidateSkillTable extends NavigationMixin(LightningElement) {
    @api recordId;                 // Candidate record ID
    @track skills = [];
    @track error;
    @track isLoading = true;

    columns = COLUMNS;
    wiredSkillsResult;

    get hasRecordId() {
        return !!this.recordId;
    }

    @wire(getCandidateSkills, { candidateId: '$recordId' })
    wiredSkills(result) {
        this.wiredSkillsResult = result;
        const { data, error } = result;

        if (data) {
            this.skills = data.map(item => ({
                id: item.Id,
                skillName: item.Skill__r?.Name || '—',
                recordName: item.Name,
                recordUrl: `/lightning/r/Candidate_Skill__c/${item.Id}/view`,
                proficiencyLevel: item.Proficiency_Level__c || '—',
                hasExperience: item.Years_of_Experience_with_Skill__c,
                hasExperienceLabel: item.Years_of_Experience_with_Skill__c ? 'Yes' : 'No',
                isVerified: item.Is_Verified__c,
                verifiedByName: item.Verified_By__r?.Name || '—'
            }));
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error.body?.message || 'Unknown error loading candidate skills.';
            this.isLoading = false;
            this.showToast('Error', 'Failed to load candidate skills', 'error');
        }
    }

    handleNew() {
        if (!this.recordId) return;
        const defaultValues = `Candidate__c=${this.recordId}`;
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Candidate_Skill__c',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: defaultValues
            }
        });
    }

    refresh() {
        if (this.wiredSkillsResult) {
            this.isLoading = true;
            refreshApex(this.wiredSkillsResult)
                .then(() => {
                    this.showToast('Success', 'Skill list refreshed', 'success');
                })
                .catch(() => {
                    this.showToast('Error', 'Refresh failed', 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}