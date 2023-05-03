import 'package:flutter/widgets.dart';

// Internal package
import 'package:bb/helpers/class_helper.dart';
import 'package:bb/models/basket_model.dart';
import 'package:bb/models/brew_model.dart';
import 'package:bb/models/company_model.dart';
import 'package:bb/models/equipment_model.dart';
import 'package:bb/models/event_model.dart';
import 'package:bb/models/fermentable_model.dart';
import 'package:bb/models/hop_model.dart';
import 'package:bb/models/inventory_model.dart';
import 'package:bb/models/misc_model.dart';
import 'package:bb/models/model.dart';
import 'package:bb/models/product_model.dart';
import 'package:bb/models/purchase_model.dart';
import 'package:bb/models/rating_model.dart';
import 'package:bb/models/receipt_model.dart';
import 'package:bb/models/style_model.dart';
import 'package:bb/models/user_model.dart';
import 'package:bb/models/yeast_model.dart';
import 'package:bb/utils/constants.dart' as CS;

// External package
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Database {
  static final firestore = FirebaseFirestore.instance;

  final baskets = firestore.collection("baskets");
  final brews = firestore.collection("brews");
  final companies = firestore.collection("companies");
  final equipments = firestore.collection("equipments");
  final events = firestore.collection("events");
  final fermentables = firestore.collection("fermentables");
  final fermenters = firestore.collection("fermenters");
  final hops = firestore.collection("hops");
  final inventory = firestore.collection("inventory");
  final miscellaneous = firestore.collection("miscellaneous");
  final products = firestore.collection("products");
  final purchases = firestore.collection("purchases");
  final ratings = firestore.collection("ratings");
  final receipts = firestore.collection("receipts");
  final styles = firestore.collection("styles");
  final users = firestore.collection("users");
  final yeasts = firestore.collection("yeasts");

  // Authentification
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? getTableName(dynamic o) {
    if (o is BasketModel) {
      return baskets;
    } else if (o is BrewModel) {
      return brews;
    } else if (o is CompanyModel) {
      return companies;
    } else if (o is EquipmentModel) {
      return equipments;
    } else if (o is EventModel) {
      return events;
    } else if (o is FermentableModel) {
      return fermentables;
    } else if (o is HopModel) {
      return hops;
    } else if (o is InventoryModel) {
      return inventory;
    } else if (o is MiscModel) {
      return miscellaneous;
    } else if (o is ProductModel) {
      return products;
    } else if (o is PurchaseModel) {
      return purchases;
    } else if (o is RatingModel) {
      return ratings;
    } else if (o is ReceiptModel) {
      return receipts;
    } else if (o is StyleModel) {
      return styles;
    } else if (o is UserModel) {
      return users;
    } else if (o is YeastModel) {
      return yeasts;
    }
    return null;
  }

  Future<void> copy(String from, String to) async {
    await firestore.collection(from).get().then((result) async {
      result.docs.forEach((doc) async {
        await firestore.collection(to).add(doc.data());
      });
    });
  }

  Future<String> add(dynamic d, {bool? ignoreAuth = false}) async {
    try {
      if (ignoreAuth == false && d is Model && _auth.currentUser != null) {
        d.creator = _auth.currentUser!.uid;
      }
      DocumentReference document = await getTableName(d)!.add(d.toMap());
      d.uuid = document.id;
    }
    catch (e, s) {
      debugPrint(s.toString());
      throw e;
    }
    return d.uuid;
  }

  Future<bool> set(String id, dynamic d, {bool? ignoreAuth = false}) async {
    try {
      if (ignoreAuth == false && d is Model && _auth.currentUser != null) {
        d.creator = _auth.currentUser!.uid;
      }
      bool updated = await getTableName(d)!.doc(id).set(d.toMap()).then((value) {
        return true;
      }).catchError((error) {
        return false;
      });
      return updated;
    }
    catch (e, s) {
      debugPrint(s.toString());
      throw e;
    }
  }

  //Returns document iD if the record is created, null is updated.
  Future<String?> update(dynamic d, {bool updateAll = true}) async {
    if (d.uuid == null) {
      return add(d);
    }
    try {
      if (updateAll == true) {
        if (ClassHelper.hasStatus(d) && d.status == CS.Status.disabled) {
          d.status = CS.Status.pending;
        }
        if (d is Model && _auth.currentUser != null) {
          d.creator = _auth.currentUser!.uid;
        }
      }
      await getTableName(d)!.doc(d.uuid).update(d.toMap());
    }
    catch (e, s) {
      debugPrint(s.toString());
      throw e;
    }
  }

  Future<void> publishAll() async {
    await publish(events);
    await publish(receipts);
    await publish(styles);
  }

  Future<void> publish(CollectionReference collection, {bool push = false}) async {
    Query query = collection.where('status', isEqualTo: Status.pending.index);
    await query.get().then((result) async {
      result.docs.forEach((doc) {
        bool canBeUpdated = true;
        Map<String, dynamic> map = doc.data() as Map<String, dynamic>;
        if (_auth.currentUser != null) {
          String? creator = map['creator'];
          canBeUpdated = creator == null || _auth.currentUser!.uid == map['creator'];
        }
        if (canBeUpdated) {
          collection.doc(doc.id).update({'status': CS.Status.publied.index});
        }
      });
    });
  }

  Future<void> delete(dynamic d, {bool forced = false}) async {
    try {
      if (forced == true || (ClassHelper.hasStatus(d) && d.status == CS.Status.disabled)) {
        return await getTableName(d)!.doc(d.uuid).delete();
      } else {
        if (ClassHelper.hasStatus(d)) {
          d.status = CS.Status.disabled;
        }
        await getTableName(d)!.doc(d.uuid).update(d.toMap());
      }
    }
    catch (e, s) {
      debugPrint(s.toString());
      throw e;
    }
  }

  Future<UserModel?> getUser(String uuid) async {
    DocumentSnapshot snapshot = await users.doc(uuid).get();
    if (snapshot.exists) {
      UserModel model = UserModel();
      model.uuid = snapshot.id;
      model.fromMap(snapshot.data() as Map<String, dynamic>);
      return model;
    }
    return null;
  }

  Future<EventModel?> getEvent(String uuid) async {
    DocumentSnapshot snapshot = await events.doc(uuid).get();
    if (snapshot.exists) {
      EventModel model = EventModel();
      model.uuid = snapshot.id;
      model.fromMap(snapshot.data() as Map<String, dynamic>);
      return model;
    }
    return null;
  }

  Future<List<EventModel>> getEvents({String? searchText, bool archived = false, bool all = false, bool ordered = true}) async {
    List<EventModel> list = [];
    Query query = events;
    if (all == false) {
      if (archived == true) {
        query = query.where('status', isEqualTo: CS.Status.disabled.index);
      } else {
        query = query.where('status', isLessThanOrEqualTo: CS.Status.publied.index);
      }
    }
    await query.get().then((result) {
      result.docs.forEach((doc) {
        bool canBeAdded = true;
        if (searchText != null && searchText.length > 0) {
          canBeAdded = false;
          String title = doc['title'].toString();
          String text = doc['text'].toString();
          if (title.toLowerCase().contains(searchText.toLowerCase()) ||
              text.toLowerCase().contains(searchText.toLowerCase())) {
            canBeAdded = true;
          }
        }
        if (canBeAdded) {
          EventModel model = EventModel();
          model.uuid = doc.id;
          model.fromMap(doc.data() as Map<String, dynamic>);
          list.add(model);
        }
      });
    });
    if (ordered == true) {
      list.sort((a, b) => a.title!.toLowerCase().compareTo(b.title!.toLowerCase()));
    }
    return list;
  }

  Future<ReceiptModel?> getReceipt(String uuid) async {
    DocumentSnapshot snapshot = await receipts.doc(uuid).get();
    if (snapshot.exists) {
      ReceiptModel model = ReceiptModel();
      model.uuid = snapshot.id;
      await model.fromMap(snapshot.data() as Map<String, dynamic>);
      return model;
    }
    return null;
  }

  Future<List<ReceiptModel>> getReceipts({String? searchText, String? user, bool? myData, bool all = false, bool ordered = true}) async {
    List<ReceiptModel> list = [];
    Query query = receipts;
    if (all == false) {
      if (myData == false || user == null) {
        query = query.where('shared', isEqualTo: true);
      } else if (user != null) {
        query = query.where('creator', isEqualTo: user);
      }
    }
    await query.get().then((result) async {
      for(QueryDocumentSnapshot doc in result.docs) {
        bool canBeAdded = true;
        if (searchText != null && searchText.length > 0) {
          canBeAdded = false;
          String title = doc['title'].toString();
          String text = doc['text'].toString();
          if (title.toLowerCase().contains(searchText.toLowerCase()) ||
              text.toLowerCase().contains(searchText.toLowerCase())) {
            canBeAdded = true;
          }
        }
        if (canBeAdded) {
          ReceiptModel model = ReceiptModel();
          model.uuid = doc.id;
          await model.fromMap(doc.data() as Map<String, dynamic>);
          list.add(model);
        }
      };
    });
    if (ordered == true) {
      list.sort((a, b) => a.title!.toString().toLowerCase().compareTo(b.title!.toString().toLowerCase()));
    }
    return list;
  }

  Future<CompanyModel?> getCompany(String uuid) async {
    DocumentSnapshot snapshot = await companies.doc(uuid).get();
    if (snapshot.exists) {
      CompanyModel model = CompanyModel();
      model.uuid = snapshot.id;
      model.fromMap(snapshot.data() as Map<String, dynamic>);
      return model;
    }
    return null;
  }


  Future<List<CompanyModel>> getCompanies({bool ordered = false}) async {
    List<CompanyModel> list = [];
    Query query = companies;
    query = query.orderBy('updated_at', descending: true);
    await query.get().then((result) {
      result.docs.forEach((doc) {
        CompanyModel model = CompanyModel();
        model.uuid = doc.id;
        model.fromMap(doc.data() as Map<String, dynamic>);
        list.add(model);
      });
    });
    if (ordered == true) {
      list.sort((a, b) => a.name!.toLowerCase().compareTo(b.name!.toLowerCase()));
    }
    return list;
  }

  Future<StyleModel?> getStyle(String uuid) async {
    DocumentSnapshot snapshot = await styles.doc(uuid).get();
    if (snapshot.exists) {
      StyleModel model = StyleModel();
      model.uuid = snapshot.id;
      model.fromMap(snapshot.data() as Map<String, dynamic>);
      return model;
    }
    return null;
  }

  Future<List<StyleModel>> getStyles({List<CS.Fermentation>? fermentations, String? name, String? number, bool ordered = false}) async {
    List<StyleModel> list = [];
    Query query = styles;
    if (name != null) {
      query = query.where('name', isEqualTo: name);
    }
    if (number != null) {
      query = query.where('number', isEqualTo: number);
    }
    query = query.orderBy('updated_at', descending: true);
    await query.get().then((result) {
      result.docs.forEach((doc) {
        bool canBeAdded = true;
        if (fermentations != null && fermentations.length > 0) {
          CS.Fermentation fermentation = CS.Fermentation.values.elementAt(doc['fermentation']);
          canBeAdded = fermentations.contains(fermentation);
        }
        if (canBeAdded) {
          StyleModel model = StyleModel();
          model.uuid = doc.id;
          model.fromMap(doc.data() as Map<String, dynamic>);
          list.add(model);
        }
      });
    });
    if (ordered == true) {
      list.sort((a, b) => a.name!.compareTo(b.name!));
    }
    return list;
  }

  Future<ProductModel?> getProduct(String uuid) async {
    DocumentSnapshot snapshot = await products.doc(uuid).get();
    if (snapshot.exists) {
      ProductModel model = ProductModel();
      model.uuid = snapshot.id;
      model.fromMap(snapshot.data() as Map<String, dynamic>);
      return model;
    }
    return null;
  }

  Future<List<ProductModel>> getProducts({Product? product, String? company, String? receipt, bool ordered = false}) async {
    List<ProductModel> list = [];
    Query query = products;
    if (product != null) {
      query = query.where('product', isEqualTo: product.index);
    }
    if (company != null) {
      query = query.where('company', isEqualTo: company);
    }
    if (receipt != null) {
      query = query.where('receipt', isEqualTo: receipt);
    }
    query = query.orderBy('updated_at', descending: true);
    await query.get().then((result) {
      result.docs.forEach((doc) {
        ProductModel model = ProductModel();
        model.uuid = doc.id;
        model.fromMap(doc.data() as Map<String, dynamic>);
        list.add(model);
      });
    });
    if (ordered == true) {
      list.sort((a, b) => a.title!.toLowerCase().compareTo(b.title!.toLowerCase()));
    }
    return list;
  }

  Future<List<RatingModel>> getRatings({String? beer, bool ordered = false}) async {
    List<RatingModel> list = [];
    Query query = ratings;
    if (beer != null) {
      query = query.where('beer', isEqualTo: beer);
    }
    query = query.orderBy('updated_at', descending: true);
    await query.get().then((result) {
      result.docs.forEach((doc) {
        RatingModel model = RatingModel();
        model.uuid = doc.id;
        model.fromMap(doc.data() as Map<String, dynamic>);
        list.add(model);
      });
    });
    return list;
  }

  Future<List<PurchaseModel>> getPurchases({String? user, bool ordered = false}) async {
    List<PurchaseModel> list = [];
    Query query = purchases;
    if (user != null) {
      query = query.where('creator', isEqualTo: user);
    }
    query = query.orderBy('updated_at', descending: true);
    await query.get().then((result) {
      result.docs.forEach((doc) {
        PurchaseModel model = PurchaseModel();
        model.uuid = doc.id;
        model.fromMap(doc.data() as Map<String, dynamic>);
        list.add(model);
      });
    });
    return list;
  }

  Future<FermentableModel?> getFermentable(String uuid) async {
    DocumentSnapshot snapshot = await fermentables.doc(uuid).get();
    if (snapshot.exists) {
      FermentableModel model = FermentableModel();
      model.uuid = snapshot.id;
      model.fromMap(snapshot.data() as Map<String, dynamic>);
      return model;
    }
    return null;
  }

  Future<List<FermentableModel>> getFermentables({String? name, String? searchText, bool ordered = false}) async {
    List<FermentableModel> list = [];
    Query query = fermentables;
    if (name != null) {
      query = query.where('name', isEqualTo: name);
    }
    query = query.orderBy('updated_at', descending: true);
    await query.get().then((result) {
      result.docs.forEach((doc) {
        bool canBeAdded = true;
        if (searchText != null && searchText.length > 0) {
          canBeAdded = false;
          String name = doc['name'].toString();
          if (name.toLowerCase().contains(searchText.toLowerCase())) {
            canBeAdded = true;
          }
        }
        if (canBeAdded) {
          FermentableModel model = FermentableModel();
          model.uuid = doc.id;
          model.fromMap(doc.data() as Map<String, dynamic>);
          list.add(model);
        }
      });
    });
    if (ordered == true) {
      list.sort((a, b) => a.name!.toString().toLowerCase().compareTo(b.name!.toString().toLowerCase()));
    }
    return list;
  }

  Future<HopModel?> getHop(String uuid) async {
    DocumentSnapshot snapshot = await hops.doc(uuid).get();
    if (snapshot.exists) {
      HopModel model = HopModel();
      model.uuid = snapshot.id;
      model.fromMap(snapshot.data() as Map<String, dynamic>);
      return model;
    }
    return null;
  }

  Future<List<HopModel>> getHops({String? name, String? searchText, bool ordered = false}) async {
    List<HopModel> list = [];
    Query query = hops;
    if (name != null) {
      query = query.where('name', isEqualTo: name);
    }
    query = query.orderBy('updated_at', descending: true);
    await query.get().then((result) {
      result.docs.forEach((doc) {
        bool canBeAdded = true;
        if (searchText != null && searchText.length > 0) {
          canBeAdded = false;
          String name = doc['name'].toString();
          if (name.toLowerCase().contains(searchText.toLowerCase())) {
            canBeAdded = true;
          }
        }
        if (canBeAdded) {
          HopModel model = HopModel();
          model.uuid = doc.id;
          model.fromMap(doc.data() as Map<String, dynamic>);
          list.add(model);
        }
      });
    });
    if (ordered == true) {
      list.sort((a, b) => a.name!.toString().toLowerCase().compareTo(b.name!.toString().toLowerCase()));
    }
    return list;
  }

  Future<MiscModel?> getMisc(String uuid) async {
    DocumentSnapshot snapshot = await miscellaneous.doc(uuid).get();
    if (snapshot.exists) {
      MiscModel model = MiscModel();
      model.uuid = snapshot.id;
      model.fromMap(snapshot.data() as Map<String, dynamic>);
      return model;
    }
    return null;
  }

  Future<List<MiscModel>> getMiscellaneous({String? name, String? searchText, bool ordered = false}) async {
    List<MiscModel> list = [];
    Query query = miscellaneous;
    if (name != null) {
      query = query.where('name', isEqualTo: name);
    }
    query = query.orderBy('updated_at', descending: true);
    await query.get().then((result) {
      result.docs.forEach((doc) {
        bool canBeAdded = true;
        if (searchText != null && searchText.length > 0) {
          canBeAdded = false;
          String name = doc['name'].toString();
          if (name.toLowerCase().contains(searchText.toLowerCase())) {
            canBeAdded = true;
          }
        }
        if (canBeAdded) {
          MiscModel model = MiscModel();
          model.uuid = doc.id;
          model.fromMap(doc.data() as Map<String, dynamic>);
          list.add(model);
        }
      });
    });
    if (ordered == true) {
      list.sort((a, b) => a.name!.toString().toLowerCase().compareTo(b.name!.toString().toLowerCase()));
    }
    return list;
  }

  Future<YeastModel?> getYeast(String uuid) async {
    DocumentSnapshot snapshot = await yeasts.doc(uuid).get();
    if (snapshot.exists) {
      YeastModel model = YeastModel();
      model.uuid = snapshot.id;
      model.fromMap(snapshot.data() as Map<String, dynamic>);
      return model;
    }
    return null;
  }

  Future<List<YeastModel>> getYeasts({String? name, String? searchText, bool ordered = false}) async {
    List<YeastModel> list = [];
    Query query = yeasts;
    if (name != null) {
      query = query.where('name', isEqualTo: name);
    }
    query = query.orderBy('updated_at', descending: true);
    await query.get().then((result) {
      result.docs.forEach((doc) {
        Map<String, dynamic>? map = doc.data() as Map<String, dynamic>;
        bool canBeAdded = true;
        if (searchText != null && searchText.length > 0) {
          canBeAdded = false;
          String name = doc['name'].toString();
          String reference = map['product'] ?? '';
          String laboratory = map['laboratory'] ?? '';
          if (name.toLowerCase().contains(searchText.toLowerCase()) ||
            reference.toLowerCase().contains(searchText.toLowerCase()) ||
            laboratory.toLowerCase().contains(searchText.toLowerCase())) {
            canBeAdded = true;
          }
        }
        if (canBeAdded) {
          YeastModel model = YeastModel();
          model.uuid = doc.id;
          model.fromMap(map);
          list.add(model);
        }
      });
    });
    if (ordered == true) {
      list.sort((a, b) => a.name!.toString().toLowerCase().compareTo(b.name!.toString().toLowerCase()));
    }
    return list;
  }

  Future<InventoryModel?> getInventory(String uuid) async {
    DocumentSnapshot snapshot = await inventory.doc(uuid).get();
    if (snapshot.exists) {
      InventoryModel model = InventoryModel();
      model.uuid = snapshot.id;
      model.fromMap(snapshot.data() as Map<String, dynamic>);
      return model;
    }
    return null;
  }

  Future<List<InventoryModel>> getInventories({CS.Ingredient? ingredient, bool ordered = false}) async {
    List<InventoryModel> list = [];
    Query query = inventory;
    if (ingredient != null) {
      query = query.where('ingredient', isEqualTo: ingredient.index);
    }
    query = query.orderBy('updated_at', descending: true);
    await query.get().then((result) {
      result.docs.forEach((doc) {
        InventoryModel model = InventoryModel();
        model.uuid = doc.id;
        model.fromMap(doc.data() as Map<String, dynamic>);
        list.add(model);
      });
    });
    if (ordered == true) {
      // list.sort((a, b) => a.name!.toString().toLowerCase().compareTo(b.name!.toString().toLowerCase()));
    }
    return list;
  }

  Future<BrewModel?> getBrew(String uuid) async {
    DocumentSnapshot snapshot = await brews.doc(uuid).get();
    if (snapshot.exists) {
      BrewModel model = BrewModel();
      model.uuid = snapshot.id;
      await model.fromMap(snapshot.data() as Map<String, dynamic>);
      return model;
    }
    return null;
  }

  Future<List<BrewModel>> getBrews({String? user, bool ordered = false}) async {
    List<BrewModel> list = [];
    Query query = brews;
    if (user != null) {
      query = query.where('creator', isEqualTo: user);
    }
    query = query.orderBy('updated_at', descending: true);
    await query.get().then((result) async {
      for(QueryDocumentSnapshot doc in result.docs) {
        BrewModel model = BrewModel();
        model.uuid = doc.id;
        await model.fromMap(doc.data() as Map<String, dynamic>);
        list.add(model);
      };
    });
    if (ordered == true) {
      list.sort((a, b) => a.inserted_at!.toString().toLowerCase().compareTo(b.inserted_at!.toString().toLowerCase()));
    }
    return list;
  }

  Future<EquipmentModel?> getEquipment(String uuid) async {
    DocumentSnapshot snapshot = await equipments.doc(uuid).get();
    if (snapshot.exists) {
      EquipmentModel model = EquipmentModel();
      model.uuid = snapshot.id;
      model.fromMap(snapshot.data() as Map<String, dynamic>);
      return model;
    }
    return null;
  }

  Future<List<EquipmentModel>> getEquipments({Equipment? type, String? searchText, bool ordered = false}) async {
    List<EquipmentModel> list = [];
    Query query = equipments;
    if (type != null) {
      query = query.where('type', isEqualTo: type.index);
    }
    query = query.orderBy('updated_at', descending: true);
    await query.get().then((result) {
      result.docs.forEach((doc) {
        Map<String, dynamic>? map = doc.data() as Map<String, dynamic>;
        bool canBeAdded = true;
        if (searchText != null && searchText.length > 0) {
          canBeAdded = false;
          String name = map['name'] ?? '';
          if (name.toLowerCase().contains(searchText.toLowerCase())) {
            canBeAdded = true;
          }
        }
        if (canBeAdded) {
          EquipmentModel model = EquipmentModel();
          model.uuid = doc.id;
          model.fromMap(map);
          list.add(model);
        }
      });
    });
    if (ordered == true) {
      // list.sort((a, b) => a.name!.toString().toLowerCase().compareTo(b.name!.toString().toLowerCase()));
    }
    return list;
  }
}
