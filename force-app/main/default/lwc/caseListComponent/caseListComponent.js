import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getCaseList from '@salesforce/apex/SupportCaseTriggerHandler.getCaseList';
import getMyCases from '@salesforce/apex/SupportCaseTriggerHandler.getMyCases';
import checkUserPermissions from '@salesforce/apex/SupportCaseTriggerHandler.checkUserPermissions';
import updateCaseStatus from '@salesforce/apex/SupportCaseTriggerHandler.updateCaseStatus';

const COLUMNS = [
    {
        label: 'Case Number',
        fieldName: 'caseUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'Case_Number__c' },
            target: '_blank'
        },
        sortable: true
    },
    {
        label: 'Subject',
        fieldName: 'Subject__c',
        type: 'text',
        sortable: true,
        wrapText: true
    },
    {
        label: 'Priority',
        fieldName: 'Priority__c',
        type: 'text',
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'priorityClass' }
        }
    },
    {
        label: 'Status',
        fieldName: 'Status__c',
        type: 'text',
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'statusClass' }
        }
    },
    {
        label: 'Created Date',
        fieldName: 'CreatedDate',
        type: 'date',
        typeAttributes: {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        },
        sortable: true
    },
    {
        label: 'Contact',
        fieldName: 'contactUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'contactName' },
            target: '_blank'
        },
        sortable: true
    },
    {
        label: 'Quick Actions',
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Set In Progress', name: 'in_progress' },
                { label: 'Set Waiting on Customer', name: 'waiting' },
                { label: 'Set Resolved', name: 'resolved' },
                { label: 'Set On Hold', name: 'on_hold' }
            ]
        }
    }
];

export default class CaseListComponent extends LightningElement {
    @track cases = [];
    @track filteredCases = [];
    @track isLoading = false;
    @track error;
    @track searchKey = '';
    @track selectedPriority = 'All';
    @track selectedStatus = 'All';
    @track sortBy = 'CreatedDate';
    @track sortDirection = 'desc';
    @track isManager = false;
    @track viewMode = 'my'; // 'my' or 'all'

    columns = COLUMNS;
    wiredCasesResult;

    // View mode options for managers
    get viewModeOptions() {
        return [
            { label: 'My Cases', value: 'my' },
            { label: 'All Cases', value: 'all' }
        ];
    }

    // Priority filter options
    priorityOptions = [
        { label: 'All Priorities', value: 'All' },
        { label: 'High', value: 'High' },
        { label: 'Medium', value: 'Medium' },
        { label: 'Low', value: 'Low' }
    ];

    // Status filter options
    statusOptions = [
        { label: 'All Statuses', value: 'All' },
        { label: 'New', value: 'New' },
        { label: 'Open', value: 'Open' },
        { label: 'In Progress', value: 'In Progress' },
        { label: 'Waiting on Customer', value: 'Waiting on customer' },
        { label: 'On Hold', value: 'On Hold' }
    ];

    // Check user permissions on component initialization
    connectedCallback() {
        this.checkPermissions();
    }

    async checkPermissions() {
        try {
            const permissions = await checkUserPermissions();
            this.isManager = permissions.isManager;
            
            // If not a manager, force view mode to 'my'
            if (!this.isManager) {
                this.viewMode = 'my';
            }
        } catch (error) {
            console.error('Error checking permissions:', error);
            this.isManager = false;
            this.viewMode = 'my';
        }
    }

    @wire(getMyCases)
    wiredMyCases(result) {
        if (this.viewMode === 'my') {
            this.handleWiredResult(result);
        }
    }

    @wire(getCaseList)
    wiredAllCases(result) {
        if (this.viewMode === 'all' && this.isManager) {
            this.handleWiredResult(result);
        }
    }

    handleWiredResult(result) {
        this.wiredCasesResult = result;
        if (result.data) {
            this.cases = result.data.map(caseRecord => {
                return {
                    ...caseRecord,
                    caseUrl: `/lightning/r/Support_Case__c/${caseRecord.Id}/view`,
                    contactUrl: caseRecord.Contact__c ? `/lightning/r/Contact/${caseRecord.Contact__c}/view` : null,
                    contactName: caseRecord.Contact__r ? caseRecord.Contact__r.Name : 'No Contact',
                    priorityClass: this.getPriorityClass(caseRecord.Priority__c),
                    statusClass: this.getStatusClass(caseRecord.Status__c)
                };
            });
            this.applyFilters();
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.cases = [];
            this.filteredCases = [];
        }
    }

    getPriorityClass(priority) {
        switch (priority) {
            case 'High':
                return 'slds-text-color_error slds-text-title_bold';
            case 'Medium':
                return 'slds-text-color_warning';
            case 'Low':
                return 'slds-text-color_success';
            default:
                return '';
        }
    }

    getStatusClass(status) {
        switch (status) {
            case 'New':
                return 'slds-text-color_weak';
            case 'Open':
                return 'slds-text-color_default';
            case 'In Progress':
                return 'slds-text-color_warning';
            case 'Waiting on customer':
                return 'slds-text-color_error';
            case 'Resolved':
                return 'slds-text-color_success';
            case 'On Hold':
                return 'slds-text-color_weak';
            default:
                return '';
        }
    }

    handleViewModeChange(event) {
        this.viewMode = event.detail.value;
        this.refreshData();
    }

    handleSearch(event) {
        this.searchKey = event.target.value.toLowerCase();
        this.applyFilters();
    }

    handlePriorityChange(event) {
        this.selectedPriority = event.detail.value;
        this.applyFilters();
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.applyFilters();
    }

    applyFilters() {
        let filtered = [...this.cases];

        // Apply search filter
        if (this.searchKey) {
            filtered = filtered.filter(caseRecord => 
                (caseRecord.Subject__c && caseRecord.Subject__c.toLowerCase().includes(this.searchKey)) ||
                (caseRecord.Case_Number__c && caseRecord.Case_Number__c.toLowerCase().includes(this.searchKey)) ||
                (caseRecord.contactName && caseRecord.contactName.toLowerCase().includes(this.searchKey))
            );
        }

        // Apply priority filter
        if (this.selectedPriority !== 'All') {
            filtered = filtered.filter(caseRecord => caseRecord.Priority__c === this.selectedPriority);
        }

        // Apply status filter
        if (this.selectedStatus !== 'All') {
            filtered = filtered.filter(caseRecord => caseRecord.Status__c === this.selectedStatus);
        }

        this.filteredCases = filtered;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        let newStatus;
        switch (actionName) {
            case 'in_progress':
                newStatus = 'In Progress';
                break;
            case 'waiting':
                newStatus = 'Waiting on customer';
                break;
            case 'resolved':
                newStatus = 'Resolved';
                break;
            case 'on_hold':
                newStatus = 'On Hold';
                break;
            default:
                return;
        }

        this.updateStatus(row.Id, newStatus);
    }

    async updateStatus(caseId, newStatus) {
        this.isLoading = true;
        
        try {
            await updateCaseStatus({ caseId: caseId, newStatus: newStatus });
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: `Case status updated to ${newStatus}`,
                    variant: 'success'
                })
            );
            
            // Refresh the data
            await refreshApex(this.wiredCasesResult);
            
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error updating case',
                    message: error.body ? error.body.message : 'Unknown error',
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData();
    }

    sortData() {
        let parseData = JSON.parse(JSON.stringify(this.filteredCases));
        
        let keyValue = (a) => {
            return a[this.sortBy];
        };
        
        let isReverse = this.sortDirection === 'asc' ? 1 : -1;
        
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : '';
            y = keyValue(y) ? keyValue(y) : '';
            
            return isReverse * ((x > y) - (y > x));
        });
        
        this.filteredCases = parseData;
    }

    refreshData() {
        this.isLoading = true;
        
        // Determine which wire to refresh based on view mode and permissions
        let refreshPromise;
        if (this.viewMode === 'all' && this.isManager) {
            refreshPromise = refreshApex(this.wiredCasesResult);
        } else {
            refreshPromise = refreshApex(this.wiredCasesResult);
        }
        
        refreshPromise
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Case list refreshed',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error refreshing data',
                        message: error.body ? error.body.message : 'Unknown error',
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get cardTitle() {
        if (this.isManager && this.viewMode === 'all') {
            return 'All Support Cases';
        }
        return 'My Support Cases';
    }

    get showViewModeSelector() {
        return this.isManager;
    }

    get hasData() {
        return this.filteredCases && this.filteredCases.length > 0;
    }

    get noDataMessage() {
        if (this.cases.length === 0) {
            return 'No cases found.';
        }
        return 'No cases match the current filters.';
    }
}