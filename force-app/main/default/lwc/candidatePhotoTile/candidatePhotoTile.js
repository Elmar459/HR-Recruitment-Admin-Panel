import { LightningElement, api, wire } from 'lwc';
import getPhotoUrl from '@salesforce/apex/CandidatePhotoManager.getPhotoUrl';
import getCandidateBasicInfo from '@salesforce/apex/CandidatePhotoManager.getCandidateBasicInfo';
import updateCandidateFields from '@salesforce/apex/CandidatePhotoManager.updateCandidateFields';
import savePhoto from '@salesforce/apex/CandidatePhotoManager.savePhoto';
import createContentVersion from '@salesforce/apex/CandidatePhotoManager.createContentVersion';
import getContentDocumentId from '@salesforce/apex/CandidatePhotoManager.getContentDocumentId';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CandidatePhotoTile extends LightningElement {
    @api recordId;

    isLoading = false;
    editingEmail = false;
    editEmailValue = '';
    editingPhone = false;
    editPhoneValue = '';

    candidateInfo = null;
    photoUrl = null;

    connectedCallback() {
        this.loadCandidateInfo();
        // Запускаем опрос каждые 3 секунды, чтобы подхватывать изменения имени и других полей
        this.pollingInterval = setInterval(() => {
            this.loadCandidateInfo();
        }, 3000);
    }

    disconnectedCallback() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
        }
    }

    // Загружаем фото через wire (cacheable=true)
    @wire(getPhotoUrl, { candidateId: '$recordId' })
    wiredPhoto(result) {
        if (result.data) {
            this.photoUrl = result.data;
        } else if (result.error) {
            console.error('Error loading photo', result.error);
        }
    }

    // Императивная загрузка информации (без кэширования)
    loadCandidateInfo() {
        if (!this.recordId) return;
        getCandidateBasicInfo({ candidateId: this.recordId })
            .then(data => {
                this.candidateInfo = data;
            })
            .catch(error => {
                console.error('Error loading candidate info', error);
            });
    }

    // ========== РЕДАКТИРОВАНИЕ EMAIL ==========
    startEditEmail() {
        if (!this.candidateInfo) return;
        this.editEmailValue = this.candidateInfo.email || '';
        this.editingEmail = true;
        setTimeout(() => {
            const input = this.template.querySelector('lightning-input[type="email"]');
            if (input) input.focus();
        }, 50);
    }

    handleEmailChange(event) {
        this.editEmailValue = event.target.value;
    }

    handleEmailKeyup(event) {
        if (event.key === 'Enter') this.saveEmail();
        else if (event.key === 'Escape') this.cancelEditEmail();
    }

    saveEmail() {
        const newEmail = this.editEmailValue?.trim();
        if (newEmail === this.candidateInfo.email) {
            this.editingEmail = false;
            return;
        }
        if (newEmail && !/^\S+@\S+\.\S+$/.test(newEmail)) {
            this.showToast('Error', 'Please enter a valid email address.', 'error');
            return;
        }
        this.isLoading = true;
        updateCandidateFields({ candidateId: this.recordId, email: newEmail, phone: null })
            .then(result => {
                if (result) {
                    this.showToast('Error', result, 'error');
                } else {
                    this.showToast('Success', 'Email updated.', 'success');
                    this.editingEmail = false;
                    if (this.candidateInfo) this.candidateInfo.email = newEmail;
                    this.loadCandidateInfo(); // принудительно перезагружаем
                }
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Failed to update email', 'error');
            })
            .finally(() => this.isLoading = false);
    }

    cancelEditEmail() {
        this.editingEmail = false;
        this.editEmailValue = this.candidateInfo.email;
    }

    // ========== РЕДАКТИРОВАНИЕ ТЕЛЕФОНА ==========
    startEditPhone() {
        if (!this.candidateInfo) return;
        this.editPhoneValue = this.candidateInfo.phone || '';
        this.editingPhone = true;
        setTimeout(() => {
            const input = this.template.querySelector('lightning-input[type="tel"]');
            if (input) input.focus();
        }, 50);
    }

    handlePhoneChange(event) {
        this.editPhoneValue = event.target.value;
    }

    handlePhoneKeyup(event) {
        if (event.key === 'Enter') this.savePhone();
        else if (event.key === 'Escape') this.cancelEditPhone();
    }

    savePhone() {
        const newPhone = this.editPhoneValue?.trim();
        if (newPhone === this.candidateInfo.phone) {
            this.editingPhone = false;
            return;
        }
        if (!newPhone || newPhone.length < 5) {
            this.showToast('Error', 'Please enter a valid phone number (min 5 chars).', 'error');
            return;
        }
        this.isLoading = true;
        updateCandidateFields({ candidateId: this.recordId, email: null, phone: newPhone })
            .then(result => {
                if (result) {
                    this.showToast('Error', result, 'error');
                } else {
                    this.showToast('Success', 'Phone updated.', 'success');
                    this.editingPhone = false;
                    if (this.candidateInfo) this.candidateInfo.phone = newPhone;
                    this.loadCandidateInfo();
                }
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Failed to update phone', 'error');
            })
            .finally(() => this.isLoading = false);
    }

    cancelEditPhone() {
        this.editingPhone = false;
        this.editPhoneValue = this.candidateInfo.phone;
    }

    // ========== ЗАГРУЗКА ФОТО ==========
    handleUploadClick() {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/jpeg, image/png, image/jpg';
        input.style.display = 'none';
        input.addEventListener('change', this.handleFileChange.bind(this));
        document.body.appendChild(input);
        input.click();
    }

    async handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;
        if (!file.type.match('image/jpeg') && !file.type.match('image/png')) {
            this.showToast('Error', 'Only JPEG and PNG images are allowed.', 'error');
            return;
        }
        this.isLoading = true;
        const reader = new FileReader();
        reader.onload = async () => {
            const base64 = reader.result.split(',')[1];
            try {
                const cvId = await createContentVersion({ fileName: file.name, base64Data: base64 });
                const docId = await getContentDocumentId({ contentVersionId: cvId });
                await savePhoto({ candidateId: this.recordId, contentDocumentId: docId });
                this.showToast('Success', 'Photo updated.', 'success');
                const newPhotoUrl = await getPhotoUrl({ candidateId: this.recordId });
                this.photoUrl = newPhotoUrl;
            } catch (error) {
                this.showToast('Error', error.body?.message || 'Upload failed', 'error');
            } finally {
                this.isLoading = false;
                event.target.value = '';
                event.target.remove();
            }
        };
        reader.readAsDataURL(file);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}