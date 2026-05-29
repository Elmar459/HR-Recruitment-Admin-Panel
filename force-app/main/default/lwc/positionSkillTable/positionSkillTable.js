import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getPositionSkills from '@salesforce/apex/PositionSkillController.getPositionSkills';

const COLUMNS = [
    {
        label: 'Skill',
        fieldName: 'skillName',
        type: 'text',
        initialWidth: 200
    },
    {
        label: 'Position Skill Name',
        fieldName: 'skillRecordUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'positionSkillName' },
            target: '_blank'
        },
        initialWidth: 180
    },
    {
        label: 'Minimum Level',
        fieldName: 'minimumLevel',
        type: 'text',
        initialWidth: 130
    },
    {
        label: 'Weight',
        fieldName: 'weight',
        type: 'number',
        cellAttributes: { alignment: 'center' },
        initialWidth: 100
    },
    {
        label: 'Is Mandatory',
        fieldName: 'isMandatory',
        type: 'boolean',
        initialWidth: 110
    }
];

export default class PositionSkillTable extends NavigationMixin(LightningElement) {
    @api recordId;                 // Position record ID
    @track skills = [];
    @track error;
    @track isLoading = true;

    columns = COLUMNS;
    wiredSkillsResult;

    get hasRecordId() {
        return !!this.recordId;
    }

    @wire(getPositionSkills, { positionId: '$recordId' })
    wiredSkills(result) {
        this.wiredSkillsResult = result;
        const { data, error } = result;

        if (data) {
            this.skills = data.map(item => ({
                id: item.Id,
                skillName: item.Skill__r?.Name || '—',
                positionSkillName: item.Position_Skill_Name__c || item.Name,
                skillRecordUrl: `/lightning/r/Position_Skill__c/${item.Id}/view`,
                minimumLevel: item.Minimum_Level__c || '—',
                weight: item.Weight__c,
                isMandatory: item.Is_Mandatory__c
            }));
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error.body?.message || 'Unknown error loading position skills.';
            this.isLoading = false;
            this.showToast('Error', 'Failed to load position skills', 'error');
        }
    }

    handleNewPositionSkill() {
        if (!this.recordId) return;
        const defaultValues = `Position__c=${this.recordId}`;
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Position_Skill__c',
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
                .catch(err => {
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