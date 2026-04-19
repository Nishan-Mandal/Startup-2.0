class CategoryFieldSchema {

  static const Map<String, dynamic> basicFields = {
    "formSchema": [
      {"label": "Shop/Service Name", "type": "string"},
      {"label": "Owners Name", "type": "string"},
    ],
  };

  static const Map<String, dynamic> contactFields = {
    "formSchema": [
      {"label": "Phone", "type": "string", "keyboardType": "number"},
      {"label": "Alternate Phone (Optional)", "type": "string", "keyboardType": "number"},
      {"label": "Email", "type": "string", "keyboardType": "email"},
    ],
  };

  static const Map<String, dynamic> detailedFields = {
    "formSchema": [
      {"label": "Since", "type": "string", "keyboardType": "number"},
      {"label": "Description", "type": "string", "keyboardType": "multiline"},
      {"label": "Accept Online Payments", "type": "boolean"}
    ],
  };



  static const Map<String, dynamic> socialFields = {
    "formSchema": [
      {"label": "WhatsApp", "type": "string", "keyboardType": "number"},
      {"label": "Website", "type": "string", "keyboardType": "url"},
      {"label": "Instagram", "type": "string", "keyboardType": "url"},
      {"label": "Facebook", "type": "string", "keyboardType": "url"},
      {"label": "LinkedIn", "type": "string", "keyboardType": "url"},
    ],
  };

  static const Map<String, dynamic> roomRentFields = {
    "id": "room_rent",
    "name": "Room Rent",
    "formSchema": [
      {
        "label": "Apartment Type",
        "type": "single_select",
        "options": ["1 RK", "1 BHK", "2 BHK", "3 BHK"],
      },
      {
        "label": "Available For",
        "type": "multi_select",
        "options": ["Office", "Bachelor's", "MES", "Family"],
      },
      {"label": "Room(s)", "type": "counter"},
      {"label": "Bathroom(s)", "type": "counter"},
      {"label": "Balcony(s)", "type": "counter"},
      {"label": "Floor Number", "type": "counter"},
      {"label": "Monthly Rent", "type": "currency"},
      {"label": "Electric Charge / unit", "type": "currency"},
      {"label": "Dining Room", "type": "boolean"},
      {"label": "2 Wheeler Parking", "type": "boolean"},
      {"label": "4 Wheeler Parking", "type": "boolean"},
      {"label": "CCTV Available?", "type": "boolean"},
      {"label": "Lift Available?", "type": "boolean"},
    ],
  };

  static const Map<String, dynamic> makupArtistFields = {
    "id": "makupArtistBeautyServices",
    "name": "Makup Artist/Beauty Services",
    "formSchema": [
      {"label": "Hair care", "type": "currency_range"},
      {"label": "Hair Styling", "type": "currency_range"},
      {"label": "Mekeup", "type": "currency_range"},
      {"label": "Mekeup package", "type": "currency_range"},
      {"label": "Basic makeup", "type": "currency_range"},
      {"label": "Fashion Makeup", "type": "currency_range"},
    ],
  };

  static const Map<String, dynamic> salonsMenWomen = {
    "id": "salonsMenWomen",
    "name": "Salons (Men/Women)",
    "formSchema": [
      {"label": "Hair Cut", "type": "currency_range"},
      {"label": "Hair Styling", "type": "currency_range"},
      {"label": "Hair Colour", "type": "currency_range"},
      {"label": "Hair Straightening", "type": "currency_range"},
      {"label": "Hair Blow Dry", "type": "currency_range"},
      {"label": "Hair Curling", "type": "currency_range"},
      {"label": "Hair Rebonding", "type": "currency_range"},
      {"label": "Beard Trimming", "type": "currency_range"},
      {"label": "Beard Shaving", "type": "currency_range"},
      {"label": "Full Body Waxing", "type": "currency_range"},
      {"label": "Under Arms Waxing", "type": "currency_range"},
      {"label": "Full Leg Waxing", "type": "currency_range"},
      {"label": "Face Waxing", "type": "currency_range"},
      {"label": "Hair Spa", "type": "currency_range"},
      {"label": "Hair Wash", "type": "currency_range"},
      {"label": "Face Services", "type": "currency_range"},
      {"label": "Face Bleach", "type": "currency_range"},
      {"label": "Face Clean Up", "type": "currency_range"},
      {"label": "Face D-Tan", "type": "currency_range"},
      {"label": "Facial", "type": "currency_range"},
      {"label": "Head Massage", "type": "currency_range"},
      {"label": "Manicure Services", "type": "currency_range"},
      {"label": "Pedicure Services", "type": "currency_range"},
    ],
  };

  static const Map<String, dynamic> spaAndMassage = {
    "id": "spaAndMassage",
    "name": "Spa & Massage",
    "formSchema": [
      {"label": "Deep Tissue Massage", "type": "currency_range"},
      {"label": "Dry Thai Massage", "type": "currency_range"},
      {"label": "Swedish Massage", "type": "currency_range"},
      {"label": "Balinese Massage", "type": "currency_range"},
      {"label": "Aroma Massage", "type": "currency_range"},
      {"label": "Hot Stone Massage", "type": "currency_range"},
    ],
  };
}
