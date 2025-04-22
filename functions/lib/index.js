"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.updateAllStoresLowerCase = exports.updateStoreLowerCase = exports.importStoresFromJson = exports.setInitialAdmin = exports.createStoreManagerAccount = exports.createStoreOwnerAccount = exports.createAdminAccount = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
// 어드민 계정 생성
exports.createAdminAccount = functions.https.onCall(async (request) => {
    var _a;
    if (!request.auth) {
        throw new functions.https.HttpsError("unauthenticated", "인증이 필요합니다.");
    }
    const callerUid = request.auth.uid;
    const callerDoc = await admin
        .firestore()
        .collection("users")
        .doc(callerUid)
        .get();
    if (!callerDoc.exists || ((_a = callerDoc.data()) === null || _a === void 0 ? void 0 : _a.role) !== "admin") {
        throw new functions.https.HttpsError("permission-denied", "관리자만 새로운 관리자 계정을 생성할 수 있습니다.");
    }
    const { email, password, displayName } = request.data;
    try {
        const userRecord = await admin.auth().createUser({
            email,
            password,
            displayName,
        });
        await admin.auth().setCustomUserClaims(userRecord.uid, {
            admin: true,
        });
        await admin.firestore().collection("users").doc(userRecord.uid).set({
            email,
            displayName,
            role: "admin",
            managedStores: [],
            ownedStores: [],
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: callerUid,
        });
        await admin.firestore().collection("adminLogs").add({
            action: "create_admin_account",
            targetUid: userRecord.uid,
            createdBy: callerUid,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            details: {
                email,
                displayName,
            },
        });
        return {
            success: true,
            user: {
                uid: userRecord.uid,
                email,
                displayName,
                role: "admin",
            },
        };
    }
    catch (error) {
        console.error("Error creating admin account:", error);
        throw new functions.https.HttpsError("internal", "관리자 계정 생성에 실패했습니다.");
    }
});
// 스토어 오너 계정 생성
exports.createStoreOwnerAccount = functions.https.onCall(async (request) => {
    var _a;
    if (!request.auth) {
        throw new functions.https.HttpsError("unauthenticated", "인증이 필요합니다.");
    }
    const callerUid = request.auth.uid;
    const callerDoc = await admin
        .firestore()
        .collection("users")
        .doc(callerUid)
        .get();
    if (!callerDoc.exists || ((_a = callerDoc.data()) === null || _a === void 0 ? void 0 : _a.role) !== "admin") {
        throw new functions.https.HttpsError("permission-denied", "관리자만 스토어 오너 계정을 생성할 수 있습니다.");
    }
    const { email, password, displayName, storeIds } = request.data;
    if (!storeIds || !Array.isArray(storeIds)) {
        throw new functions.https.HttpsError("invalid-argument", "유효한 스토어 ID 목록이 필요합니다.");
    }
    try {
        const userRecord = await admin.auth().createUser({
            email,
            password,
            displayName,
        });
        await admin.auth().setCustomUserClaims(userRecord.uid, {
            storeOwner: true,
        });
        await admin.firestore().collection("users").doc(userRecord.uid).set({
            email,
            displayName,
            role: "owner",
            managedStores: [],
            ownedStores: storeIds,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: callerUid,
        });
        for (const storeId of storeIds) {
            await admin.firestore().collection("stores").doc(storeId).update({
                ownerId: userRecord.uid,
            });
        }
        return {
            success: true,
            user: {
                uid: userRecord.uid,
                email,
                displayName,
                role: "owner",
                ownedStores: storeIds,
            },
        };
    }
    catch (error) {
        console.error("Error creating store owner account:", error);
        throw new functions.https.HttpsError("internal", "스토어 오너 계정 생성에 실패했습니다.");
    }
});
// 스토어 매니저 계정 생성
exports.createStoreManagerAccount = functions.https.onCall(async (request) => {
    var _a, _b;
    if (!request.auth) {
        throw new functions.https.HttpsError("unauthenticated", "인증이 필요합니다.");
    }
    const callerUid = request.auth.uid;
    const callerDoc = await admin
        .firestore()
        .collection("users")
        .doc(callerUid)
        .get();
    if (!callerDoc.exists) {
        throw new functions.https.HttpsError("permission-denied", "권한이 없습니다.");
    }
    const callerRole = (_a = callerDoc.data()) === null || _a === void 0 ? void 0 : _a.role;
    if (callerRole !== "admin" && callerRole !== "owner") {
        throw new functions.https.HttpsError("permission-denied", "관리자 또는 스토어 오너만 매니저 계정을 생성할 수 있습니다.");
    }
    const { email, password, displayName, storeIds } = request.data;
    if (!storeIds || !Array.isArray(storeIds)) {
        throw new functions.https.HttpsError("invalid-argument", "유효한 스토어 ID 목록이 필요합니다.");
    }
    if (callerRole === "owner") {
        const ownedStores = ((_b = callerDoc.data()) === null || _b === void 0 ? void 0 : _b.ownedStores) || [];
        if (!storeIds.every((id) => ownedStores.includes(id))) {
            throw new functions.https.HttpsError("permission-denied", "스토어 오너는 자신이 소유한 스토어의 매니저만 생성할 수 있습니다.");
        }
    }
    try {
        const userRecord = await admin.auth().createUser({
            email,
            password,
            displayName,
        });
        await admin.auth().setCustomUserClaims(userRecord.uid, {
            storeManager: true,
        });
        await admin.firestore().collection("users").doc(userRecord.uid).set({
            email,
            displayName,
            role: "manager",
            managedStores: storeIds,
            ownedStores: [],
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: callerUid,
        });
        for (const storeId of storeIds) {
            await admin.firestore().collection("stores").doc(storeId).update({
                managers: admin.firestore.FieldValue.arrayUnion(userRecord.uid),
            });
        }
        return {
            success: true,
            user: {
                uid: userRecord.uid,
                email,
                displayName,
                role: "manager",
                managedStores: storeIds,
            },
        };
    }
    catch (error) {
        console.error("Error creating store manager account:", error);
        throw new functions.https.HttpsError("internal", "스토어 매니저 계정 생성에 실패했습니다.");
    }
});
exports.setInitialAdmin = functions.https.onRequest(async (req, res) => {
    try {
        const userRecord = await admin.auth().getUserByEmail("breece@gmail.com");
        console.log("Found user:", userRecord.uid);
        await admin.auth().setCustomUserClaims(userRecord.uid, {
            admin: true,
        });
        console.log("Set custom claims");
        await admin.firestore().collection("users").doc(userRecord.uid).set({
            email: "breece@gmail.com",
            role: "admin",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        console.log("Updated Firestore");
        res.json({
            success: true,
            message: "Admin role set successfully",
        });
    }
    catch (error) {
        console.error("Detailed error:", error);
        res.status(500).json({
            success: false,
            error: error instanceof Error ? error.message : "Failed to set admin role",
        });
    }
});
const stores_data_1 = require("./stores-data");
exports.importStoresFromJson = functions.https.onRequest(async (req, res) => {
    var _a, _b, _c, _d, _e;
    try {
        const stores = stores_data_1.storesData.stores;
        const batch = admin.firestore().batch();
        const usedIds = new Set();
        const generateUniqueId = () => {
            let id;
            do {
                id = Math.random().toString(36).substring(2, 15);
            } while (usedIds.has(id));
            usedIds.add(id);
            return id;
        };
        const validCategories = [
            "happy_hour",
            "deals_and_discounts",
            "special_events",
            "all_you_can_eat",
        ];
        for (const store of stores) {
            const storeId = generateUniqueId();
            const storeRef = admin.firestore().collection("stores").doc(storeId);
            const averageRating = store.ratings ?
                store.ratings.reduce((a, b) => a + b, 0) / store.ratings.length :
                0;
            const storeData = {
                name: store.name,
                nameLower: store.name.toLowerCase(),
                category: Array.isArray(store.category) ?
                    store.category.filter((cat) => validCategories.includes(cat)) :
                    [],
                cuisineTypes: store.cuisineTypes || [],
                contactNumber: store.contactNumber,
                location: new admin.firestore.GeoPoint(((_a = store.location) === null || _a === void 0 ? void 0 : _a.latitude) || 0, ((_b = store.location) === null || _b === void 0 ? void 0 : _b.longitude) || 0),
                ratings: {
                    average: averageRating,
                    total: store.totalRatings,
                    scores: store.ratings || [],
                },
                menus: ((_c = store.menus) === null || _c === void 0 ? void 0 : _c.map((menu) => ({
                    id: menu.itemId,
                    name: menu.name,
                    price: menu.price,
                    type: menu.type,
                }))) || [],
                businessHours: ((_d = store.businessHours) === null || _d === void 0 ? void 0 : _d.map((hours) => ({
                    openHour: hours.openHour,
                    openMinute: hours.openMinute,
                    closeHour: hours.closeHour,
                    closeMinute: hours.closeMinute,
                    isNextDay: hours.isNextDay,
                    daysOfWeek: hours.daysOfWeek,
                }))) || [],
                happyHours: ((_e = store.happyHours) === null || _e === void 0 ? void 0 : _e.map((hours) => ({
                    startHour: hours.startHour,
                    startMinute: hours.startMinute,
                    endHour: hours.endHour,
                    endMinute: hours.endMinute,
                    isNextDay: hours.isNextDay,
                    daysOfWeek: hours.daysOfWeek,
                }))) || [],
                is24Hours: store.is24Hours || false,
                ownerId: null,
                menuCategories: [],
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            batch.set(storeRef, storeData);
        }
        await batch.commit();
        res.json({
            success: true,
            message: `${stores.length}개의 스토어가 성공적으로 등록되었습니다.`,
        });
    }
    catch (error) {
        console.error("Error importing stores:", error);
        res.status(500).json({
            success: false,
            error: error instanceof Error ? error.message : "Unknown error occurred",
        });
    }
});
exports.updateStoreLowerCase = functions.firestore
    .document("stores/{storeId}")
    .onWrite(async (change) => {
    const data = change.after.data();
    if (data === null || data === void 0 ? void 0 : data.name) {
        await change.after.ref.update({
            nameLower: data.name.toLowerCase(),
        });
    }
});
exports.updateAllStoresLowerCase = functions.https.onRequest(async (_request, response) => {
    const db = admin.firestore();
    const stores = await db.collection("stores").get();
    const batch = db.batch();
    stores.docs.forEach((doc) => {
        const data = doc.data();
        if (data.name) {
            batch.update(doc.ref, { nameLower: data.name.toLowerCase() });
        }
    });
    await batch.commit();
    response.send("Updated all stores");
});
//# sourceMappingURL=index.js.map