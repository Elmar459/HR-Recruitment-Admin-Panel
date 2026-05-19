import { LightningElement, api } from 'lwc';
import rescoreApplication from '@salesforce/apex/CandidateMatchingController.rescoreApplication';
import { RefreshEvent } from 'lightning/refresh';

export default class ApplicationReScore extends LightningElement {

    @api recordId;
    isLoading = false;
    
    async handleClick() {

        this.isLoading = true;

        try {
            const score = await rescoreApplication({
                applicationId: this.recordId
            });

            console.log('New Score:', score);
            this.dispatchEvent(new RefreshEvent());

        } catch (error) {
            console.error(error);

        } finally {
            this.isLoading = false;
        }
    }
}