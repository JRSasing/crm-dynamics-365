import { IInputs, IOutputs } from "./generated/ManifestTypes";

interface Dictionary {
	[key: string]: string
}

export class RACTAddressAutoCompleteControl implements ComponentFramework.StandardControl<IInputs, IOutputs> {

	public _notifyOutputChanged: () => void;
	public inputElement: HTMLInputElement;
	private listElement: HTMLDivElement;
	private APIkey: string;
	private addressInput: string;
	private addressLine3: string;
	private unitFlatNumber: string;
	private GNaf: string;
	private longitude: string;
	private latitude: string;
	private streetNumber: string;
	private streetName: string;
	private suburb: string;
	private state: string;
	private country: string;
	private postCode: string;
	private addressOneLine: string;
	private ausbar: string;
	private dpid: string;
	private fieldLogicalName: string;
	private currentSelectedItem: number;
	private elementHover: boolean;
	private addressList: Dictionary;
	private global_address_key: string;


	constructor() {
	}

	/**
	 * Used to initialize the control instance. Controls can kick off remote server calls and other initialization actions here.
	 * Data-set values are not initialized here, use updateView.
	 * @param context The entire property bag available to control via Context Object; It contains values as set up by the customizer mapped to property names defined in the manifest, as well as utility functions.
	 * @param notifyOutputChanged A callback method to alert the framework that the control has new outputs ready to be retrieved asynchronously.
	 * @param state A piece of data that persists in one session for a single user. Can be set at any point in a controls life cycle by calling 'setControlState' in the Mode interface.
	 * @param container If a control is marked control-type='standard', it will receive an empty div element within which it can render its content.
	 */
	public init(context: ComponentFramework.Context<IInputs>, notifyOutputChanged: () => void, state: ComponentFramework.Dictionary, container: HTMLDivElement) {
		this._notifyOutputChanged = notifyOutputChanged;
		this.currentSelectedItem = -1;
		this.elementHover = false;
		this.addressList = {};

		if (context.parameters.AddressInput.attributes?.LogicalName)
			this.fieldLogicalName = context.parameters.AddressInput.attributes?.LogicalName;
		else
			this.fieldLogicalName = "";

		// Create HTML element
		this.listElement = document.createElement("div");
		this.listElement.setAttribute("id", this.fieldLogicalName + "_addressList");
		this.listElement.setAttribute("class", "autocomplete-items");

		// Create input element where user will input the address
		this.inputElement = document.createElement("input");
		this.inputElement.setAttribute("autocomplete", "inputautocompleteoff");
		this.inputElement.setAttribute("id", this.fieldLogicalName + "_search_field");
		this.inputElement.setAttribute("type", "text");
		this.inputElement.setAttribute("class", "InputAddress");
		this.inputElement.placeholder = "---";
		this.inputElement.style.paddingLeft = '0.5rem';
		this.inputElement.style.paddingRight = '0.5rem';
		this.inputElement.style.fontSize = '1.0rem';
		this.inputElement.value = context.parameters.AddressInput.raw!;
		this.inputElement.addEventListener("keyup", this.onKeyUp.bind(this));

		this.inputElement.addEventListener("focusin", () => {
			this.inputElement.className = "InputAddressFocused";
			if (this.inputElement.value == "---")
				this.inputElement.value = "";
		});

		this.inputElement.addEventListener("focusout", () => {
			this.inputElement.className = "InputAddress";
			if (this.inputElement.value == "")
				this.inputElement.value = "---";
		});

		container.addEventListener("focusout", () => {
			if (!this.elementHover) {
				this.listElement.hidden = true;
				this.addressInput = this.inputElement.value;
				if (this.addressInput != "" && this.addressInput != "---")
					this._notifyOutputChanged();
			}
		});

		var self = this;
		var fetchxmlapikeyquery = "<fetch top='1' >" +
			"<entity name='environmentvariabledefinition'>" +
			"<attribute name='defaultvalue' />" +
			"<attribute name='environmentvariabledefinitionid' />" +
			"<filter>" +
			"<condition attribute='schemaname' operator='eq' value='ract_apikey' />" +
			"</filter>" +
			"<link-entity name='environmentvariablevalue' from='environmentvariabledefinitionid' to='environmentvariabledefinitionid' link-type='outer' alias='varvalue' />" +
			"</entity>" +
			"</fetch>";

		// Fetch API Key from Configuration table
		context.webAPI.retrieveMultipleRecords("environmentvariabledefinition", "?fetchXml=" + fetchxmlapikeyquery).then(
			function (responseUserItems: ComponentFramework.WebApi.RetrieveMultipleResponse) {
				if (responseUserItems.entities.length > 0) {
					if (typeof (responseUserItems.entities[0]["varvalue.value"]) != "undefined") {
						self.APIkey = responseUserItems.entities[0]["varvalue.value"];
					}
					else if (typeof (responseUserItems.entities[0].defaultvalue) != "undefined") {
						self.APIkey = responseUserItems.entities[0].defaultvalue;

					}
					
					container.appendChild(self.inputElement);
					container.appendChild(self.listElement);

					document.addEventListener('keydown', (event) => {
						if (event.key == 'Escape' || (event.key == 'Enter' && self.currentSelectedItem == -1)) {
							self.listElement.hidden = true;
							self.addressInput = self.inputElement.value;

							if (self.addressInput != "")
								self._notifyOutputChanged();
						}
					});

					$(document).bind('IssuesReceived_'+self.fieldLogicalName, self.selectValue.bind(self));
				}
				else {
					container.innerText = "No API Key configured, kindly check Configuration table.";
				}
			}
		);
	}

	private onKeyUp(event: KeyboardEvent): void {
		if (event.key == 'ArrowDown' || event.key == 'ArrowUp') {
			event.key == 'ArrowDown' ? this.navigateOptions(true) : this.navigateOptions(false);
			return;
		}
	
		if (event.key == 'Enter' && this.currentSelectedItem != -1) {
			this.selectOption(this.currentSelectedItem,this.global_address_key);
			return;
		}
	
		if (event.key == 'Escape') {
			this.addressInput = this.inputElement.value;
			if (this.addressInput != "") {
				this._notifyOutputChanged();
			}
			return;
		}
		const url = "https://api.experianaperture.io/address/search/v1";
		const api = this.APIkey;
		const data = {
			country_iso: "AUS",
			components: {
				unspecified: [
					this.inputElement.value
				]
			},
			datasets: [
				"au-address-datafusion"
			]
		};
		const self = this;
	
		$.ajax({
			url: url,
			type: "POST",
			dataType: "json",
			contentType: "application/json",
			data: JSON.stringify(data),
			beforeSend: function(xhr) {
				xhr.setRequestHeader("Auth-Token", api);
			},
			success: function (response) {
				console.log(response);
				if (response && response.result && response.result.suggestions) {
					const addressListElement = <HTMLDivElement>document.getElementById(self.fieldLogicalName + "_addressList");
					addressListElement.innerHTML = "";
					addressListElement.hidden = false;
					// Display Address Auto Complete suggestions
					for (let suggestion of response.result.suggestions) {
						console.log("Suggestions: " + suggestion.text);
						const newDiv = document.createElement("div");
						newDiv.setAttribute("id", this.fieldLogicalName + "_suggestion");
						newDiv.textContent = suggestion.text;
						// newDiv.addEventListener("click", function () {
						// 	/*insert the value for the autocomplete text field:*/
						// 	//ract_residentialproperty_search_field
						// 	const searchField = <HTMLInputElement>document.getElementById(self.fieldLogicalName + "_search_field");
						// 	searchField.value = this.getElementsByTagName("input")[0].value;
						// 	addressListElement.innerHTML = this.getElementsByTagName("input")[0].id;
						// 	addressListElement.hidden = true;
						// 	self.global_address_key = suggestion.global_address_key;
						// 	self.addressInput = suggestion.text;
						// 	$(document).trigger('IssuesReceived');
						// });
						newDiv.addEventListener("click", function () {
							/*insert the value for the autocomplete text field:*/
							(<HTMLInputElement>document.getElementById(self.fieldLogicalName + "_search_field")).value = this.getElementsByTagName("input")[0].value;
							(<HTMLDivElement>document.getElementById(self.fieldLogicalName + "_addressList")).innerHTML = this.getElementsByTagName("input")[0].id;
							(<HTMLDivElement>document.getElementById(self.fieldLogicalName + "_addressList")).hidden = true;
							self.global_address_key = suggestion.global_address_key;
							self.addressInput = suggestion.text;
							$(document).trigger('IssuesReceived_'+self.fieldLogicalName);
						});



						newDiv.addEventListener("mouseover", function () { self.elementHover = true; });
						newDiv.addEventListener("mouseout", function () { self.elementHover = false; });
	
						const newOptionTest = document.createElement("input");
						newOptionTest.setAttribute("type", "hidden");
						newOptionTest.setAttribute("value", suggestion.text);
						newOptionTest.setAttribute("id", suggestion.global_address_key);
						self.addressList[suggestion.global_address_key] = suggestion.text;
						newDiv.appendChild(newOptionTest);
	
						addressListElement.appendChild(newDiv);
					}
				}
			},
			error: function (error) {
				console.log(error);
				// Handle error response
			}
		});
	}
	
	public getLongLat(globalAddressKey: string): void {
		const api = this.APIkey;
		const url = "https://api.experianaperture.io/enrichment/v2";
		const data = {
			country_iso: "AUS",
			keys: { global_address_key: globalAddressKey},
			attributes: {
				AUS_CV_Household: [
					"gnaf_latitude",
					"gnaf_longitude"
				]
			}
		};
		const self = this;

		$.ajax({
			url: url,
			type: "POST",
			dataType: "json",
			contentType: "application/json",
			data: JSON.stringify(data),
			beforeSend: function(xhr) {
				xhr.setRequestHeader("Auth-Token", api);
			},
			success: function (response) {
				if (response) {
					self.longitude = response.result.aus_cv_household.gnaf_longitude ? self.longitude = response.result.aus_cv_household.gnaf_longitude : self.longitude = "";
					self.latitude = response.result.aus_cv_household.gnaf_latitude ? self.latitude = response.result.aus_cv_household.gnaf_latitude : self.latitude = "";
				}
				else{
					console.log("response: "+response);
				}
			},
			error: function (error) {
				console.log(error);
				// Handle error response
			}
		})
	}

	public selectValue(): void {
		
		//selectedAddress is the global address key
		const selectedAddress = (<HTMLDataListElement>document.getElementById(this.fieldLogicalName + "_addressList")).innerHTML;
		const oneLiner = this.inputElement.value;
		console.log("selected address: "+ selectedAddress);
		console.log(this.addressList[selectedAddress]);
	
		if (!selectedAddress.startsWith("<div")) {
			if (selectedAddress != "" && this.addressList[selectedAddress]) {
				// Get information of selected Address from Auto Complete suggestions
				const url = "https://api.experianaperture.io/address/format/v1/"+selectedAddress;
				const api = this.APIkey;
				const data = {
					layouts: [
						"default"
					  ],
					  layout_format: "default"
				};
				const self = this;
	
				$.ajax({
					url: url,
					type: "POST",
					dataType: "json",
					contentType: "application/json",
					data: JSON.stringify(data),
					beforeSend: function(xhr) {
						xhr.setRequestHeader("Auth-Token", api);
						xhr.setRequestHeader("Add-Components", "true");
						xhr.setRequestHeader("Add-Metadata", "true");
					},
					success: function (response) {
						if (response) {
							console.log("Address will be broken down and fields will be updated");
							//Clean fields before updating
							self.inputElement.value = "";
							self.addressOneLine = "";
							self.addressLine3 = "";
							self.streetName = "";
							self.streetNumber = "";
							self.suburb = "";
							self.state = "";
							self.country = "";
							self.postCode = "";

							self.longitude = "";
							self.latitude = "";
							
							self.GNaf = "";
							self.ausbar	= "";
							self.dpid = "";
							
						    const selectedSuggestion = response.result.address;
							//response.result.address;
							// Remove Address Input from the field
							self.inputElement.value = oneLiner;
							self.addressOneLine = oneLiner;

							//Used by "Address (number): Name" Similar to addressOneLine, but is used to determine if there's a change on selected address. because the AddressOneLine is modified based on the other address fields.
							self.addressLine3 = oneLiner || "";

							self.streetName = response.result.components.street.full_name || "";
							self.streetNumber = response.result.components.building.building_number || "";
							self.suburb = selectedSuggestion.locality || "";
							self.state = selectedSuggestion.region || "";
							self.country = "AUSTRALIA";
							self.dpid = response.metadata.address_info.identifier.dpid || "";

							self.postCode = selectedSuggestion.postal_code || "";

							//Commented out because it's not working. Response body: Metadata might not be available for utilization
							//self.GNaf = response.metadata.address_info.identifier.gnafPid || "";
							self.GNaf = response.metadata.address_info.identifier.gnafPid ? self.GNaf = response.metadata.address_info.identifier.gnafPid : self.GNaf = "";

							self.dpid = response.metadata.address_info.identifier.dpid ? self.dpid = response.metadata.address_info.identifier.dpid : self.dpid = "";

							//delivery_point_barcode is the ausbar in experian format v1 api
							self.ausbar = response.metadata.barcode.delivery_point_barcode ? self.ausbar = response.metadata.barcode.delivery_point_barcode : self.ausbar = "";

							
							//no longitude and latitude found. Supposed to be in enrichment v1 api. but the dataset provided is limited, and cannot utilize the enrichment v1, and even the fomart v1 api's full response.
							// self.longitude = selectedSuggestion.Longitude || "";
							// self.latitude = selectedSuggestion.Latitude || "";
							
							//Get the value of Longitude and Latitude from enrichment v2 api
							self.getLongLat(selectedAddress);

							self._notifyOutputChanged();
				
							console.log("Address broken down and fields have been updated");
						}
						else{
							console.log("response: "+response);
						}
					},
					error: function (error) {
						console.log(error);
						// Handle error response
					}
				})
				.done(function(data) {
					console.log("done data: "+data);
				})
				.fail(function(data) {
					console.log("fail data: "+data);
				})
				;
				
			}
		}
	}
	
	
	

	private navigateOptions(down: boolean) {
		if (this.listElement.hidden == true)
			return;

		var options = this.listElement.childNodes;
		if (down) {
			if (this.currentSelectedItem == -1) {
				(<HTMLInputElement>options[0]).style.backgroundColor = "#e9e9e9";
				this.currentSelectedItem = 0;
			}
			else if (this.currentSelectedItem != options.length - 1) {
				(<HTMLInputElement>options[this.currentSelectedItem]).style.backgroundColor = "#fff";
				(<HTMLInputElement>options[this.currentSelectedItem + 1]).style.backgroundColor = "#e9e9e9";
				this.currentSelectedItem++;
			}
		} else {
			if (this.currentSelectedItem == -1) {
				(<HTMLInputElement>options[options.length - 1]).style.backgroundColor = "#e9e9e9";
				this.currentSelectedItem = options.length - 1;
			}
			else if (this.currentSelectedItem != 0) {
				(<HTMLInputElement>options[this.currentSelectedItem]).style.backgroundColor = "#fff";
				(<HTMLInputElement>options[this.currentSelectedItem - 1]).style.backgroundColor = "#e9e9e9";
				this.currentSelectedItem--;
			}
		}
	}

	private selectOption(index: number, globalAddressKey: string): void {
		if (this.listElement.hidden == true){
			console.log("listElement is hidden");
			return;
		}
		var options = this.listElement.childNodes;

		if (index >= 0 && index < options.length) {
			var tempValue = (<HTMLInputElement>(<HTMLInputElement>options[index]).childNodes[1]).value;
			var tempID = (<HTMLInputElement>(<HTMLInputElement>options[index]).childNodes[1]).id;
			console.log("tempValue: " + tempValue);
			console.log("tempID: " + tempID);
			this.inputElement.value = tempValue;
			this.listElement.innerHTML = tempID;
			this.listElement.hidden = true;
			this.currentSelectedItem == -1
			console.log("Proceeding to selectvalue");
			this.selectValue();
		}
	}

	/**
	 * Called when any value in the property bag has changed. This includes field values, data-sets, global values such as container height and width, offline status, control metadata values such as label, visible, etc.
	 * @param context The entire property bag available to control via Context Object; It contains values as set up by the customizer mapped to names defined in the manifest, as well as utility functions
	 */
	public updateView(Fcontext: ComponentFramework.Context<IInputs>): void {
		// Add code to update control view
	}

	/** 
	 * It is called by the framework prior to a control receiving new data. 
	 * @returns an object based on nomenclature defined in manifest, expecting object[s] for property marked as “bound” or “output”
	 */
	public getOutputs(): IOutputs {
		console.log("AddressInput: " + this.addressInput);
		console.log("UnitFlatNumber: " + this.unitFlatNumber);
		console.log("AddressStreet3: " + this.addressLine3);
		console.log("StreetNumber: " + this.streetNumber);
		console.log("StreetName: " + this.streetName);
		console.log("Suburb: " + this.suburb);
		console.log("State: " + this.state);
		console.log("Country: " + this.country);
		console.log("Postcode: " + this.postCode);
		console.log("GNaf: " + this.GNaf);
		console.log("Longitude: " + this.longitude);
		console.log("Latitude: " + this.latitude);
		console.log("DPID: " + this.dpid);
		console.log("AUSBAR: " + this.ausbar);
		
		
		console.log("Address One Line: " + this.addressOneLine);
		let input = document.getElementById(this.fieldLogicalName+ '_search_field') as HTMLInputElement;
		console.log("Input: "+ input)
		console.log(input?.value);

		if (input?.value !== null || input?.value !== undefined || input?.value !== ""){
			input!.value = "";
		}
		
		return {
			AddressInput: "",
			UnitFlatNumber: this.unitFlatNumber,
			AddressStreet3: this.addressLine3,
			StreetNumber: this.streetNumber,
			StreetName: this.streetName,
			Suburb: this.suburb,
			State: this.state,
			Country: this.country,
			Postcode: this.postCode,
			GNAF_ID: this.GNaf,
			DPID: this.dpid,
			Longitude: this.longitude.toString(),
			Latitude: this.latitude.toString(),
			AddressOneLine: this.addressOneLine
		}
		//Commented out May 30, 2023
		// if (input?.value !== null || input?.value !== undefined || input?.value !== ""){
		// 		input!.value = "";
		// }

		// if (this.unitFlatNumber === undefined || this.streetNumber === undefined || this.streetName === undefined || this.suburb === undefined || this.state === undefined || this.country === undefined 
		// 	|| this.postCode === undefined || this.longitude === undefined || this.latitude === undefined || this.GNaf === undefined || 
		// 	/** this.dpid === undefined || this.ausbar === undefined*/ this.addressOneLine === undefined) {
		// 	console.log("No changes!")
		// 	return {};
		// }
		// else {
		// 	return {
		// 		AddressInput: undefined,
		// 		UnitFlatNumber: this.unitFlatNumber,
		// 		StreetNumber: this.streetNumber,
		// 		StreetName: this.streetName,
		// 		Suburb: this.suburb,
		// 		State: this.state,
		// 		Country: this.country,
		// 		Postcode: this.postCode,
		// 		/** Commented out since not supported on /format/v1 in experian (these fields are in enrichment)
		// 		GNAF_ID: this.GNaf,
		// 		DPID: this.dpid,
		// 		*/
		// 		Longitude: this.longitude.toString(),
		// 		Latitude: this.latitude.toString(),
		// 		AddressOneLine: this.addressOneLine
		// 	}
		// }
	}

	/** 
	 * Called when the control is to be removed from the DOM tree. Controls should use this call for cleanup.
	 * i.e. cancelling any pending remote calls, removing listeners, etc.
	 */
	public destroy(): void {
		// Add code to cleanup control if necessary
	}
}