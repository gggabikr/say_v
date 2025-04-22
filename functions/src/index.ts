import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { storesData } from "./stores-data";

admin.initializeApp();

interface CreateAccountData {
  email: string;
  password: string;
  displayName: string;
  storeIds?: string[];
}

interface MenuItem {
  itemId: string;
  name: string;
  price: number;
  type: string;
}

interface Hours {
  openHour?: number;
  openMinute?: number;
  closeHour?: number;
  closeMinute?: number;
  startHour?: number;
  startMinute?: number;
  endHour?: number;
  endMinute?: number;
  isNextDay: boolean;
  daysOfWeek: string[];
}

interface StoreData {
  name: string;
  category?: string[];
  cuisineTypes?: string[];
  contactNumber?: string;
  location?: {
    latitude: number;
    longitude: number;
  };
  ratings?: number[];
  totalRatings?: number;
  menus?: MenuItem[];
  businessHours?: Hours[];
  happyHours?: Hours[];
  is24Hours?: boolean;
  [key: string]: unknown;
}

// 어드민 계정 생성
export const createAdminAccount = functions.https.onCall(
  async (request: functions.https.CallableRequest<CreateAccountData>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "인증이 필요합니다."
      );
    }

    const callerUid = request.auth.uid;
    const callerDoc = await admin
      .firestore()
      .collection("users")
      .doc(callerUid)
      .get();

    if (!callerDoc.exists || callerDoc.data()?.role !== "admin") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "관리자만 새로운 관리자 계정을 생성할 수 있습니다."
      );
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
    } catch (error) {
      console.error("Error creating admin account:", error);
      throw new functions.https.HttpsError(
        "internal",
        "관리자 계정 생성에 실패했습니다."
      );
    }
  }
);

// 스토어 오너 계정 생성
export const createStoreOwnerAccount = functions.https.onCall(
  async (request: functions.https.CallableRequest<CreateAccountData>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "인증이 필요합니다."
      );
    }

    const callerUid = request.auth.uid;
    const callerDoc = await admin
      .firestore()
      .collection("users")
      .doc(callerUid)
      .get();

    if (!callerDoc.exists || callerDoc.data()?.role !== "admin") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "관리자만 스토어 오너 계정을 생성할 수 있습니다."
      );
    }

    const { email, password, displayName, storeIds } = request.data;

    if (!storeIds || !Array.isArray(storeIds)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "유효한 스토어 ID 목록이 필요합니다."
      );
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
    } catch (error) {
      console.error("Error creating store owner account:", error);
      throw new functions.https.HttpsError(
        "internal",
        "스토어 오너 계정 생성에 실패했습니다."
      );
    }
  }
);

// 스토어 매니저 계정 생성
export const createStoreManagerAccount = functions.https.onCall(
  async (request: functions.https.CallableRequest<CreateAccountData>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "인증이 필요합니다."
      );
    }

    const callerUid = request.auth.uid;
    const callerDoc = await admin
      .firestore()
      .collection("users")
      .doc(callerUid)
      .get();

    if (!callerDoc.exists) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "권한이 없습니다."
      );
    }

    const callerRole = callerDoc.data()?.role;
    if (callerRole !== "admin" && callerRole !== "owner") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "관리자 또는 스토어 오너만 매니저 계정을 생성할 수 있습니다."
      );
    }

    const { email, password, displayName, storeIds } = request.data;

    if (!storeIds || !Array.isArray(storeIds)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "유효한 스토어 ID 목록이 필요합니다."
      );
    }

    if (callerRole === "owner") {
      const ownedStores = callerDoc.data()?.ownedStores || [];
      if (!storeIds.every((id: string) => ownedStores.includes(id))) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "스토어 오너는 자신이 소유한 스토어의 매니저만 생성할 수 있습니다."
        );
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
    } catch (error) {
      console.error("Error creating store manager account:", error);
      throw new functions.https.HttpsError(
        "internal",
        "스토어 매니저 계정 생성에 실패했습니다."
      );
    }
  }
);

export const setInitialAdmin = functions.https.onRequest(async (req, res) => {
  try {
    const userRecord = await admin.auth().getUserByEmail("breece@gmail.com");
    console.log("Found user:", userRecord.uid);

    await admin.auth().setCustomUserClaims(userRecord.uid, {
      admin: true,
    });
    console.log("Set custom claims");

    await admin.firestore().collection("users").doc(userRecord.uid).set(
      {
        email: "breece@gmail.com",
        role: "admin",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    console.log("Updated Firestore");

    res.json({
      success: true,
      message: "Admin role set successfully",
    });
  } catch (error: unknown) {
    console.error("Detailed error:", error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : "Failed to set admin role",
    });
  }
});

export const importStoresFromJson = functions.https.onRequest(
  async (req, res) => {
    try {
      const stores: StoreData[] = storesData.stores;
      const batch = admin.firestore().batch();
      const usedIds = new Set<string>();

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

        const averageRating = store.ratings
          ? store.ratings.reduce((a, b) => a + b, 0) / store.ratings.length
          : 0;

        const storeData = {
          name: store.name,
          nameLower: store.name.toLowerCase(),
          category: Array.isArray(store.category)
            ? store.category.filter((cat) => validCategories.includes(cat))
            : [],
          cuisineTypes: store.cuisineTypes || [],
          contactNumber: store.contactNumber,
          location: new admin.firestore.GeoPoint(
            store.location?.latitude || 0,
            store.location?.longitude || 0
          ),
          ratings: {
            average: averageRating,
            total: store.totalRatings,
            scores: store.ratings || [],
          },
          menus: store.menus?.map((menu: MenuItem) => ({
            id: menu.itemId,
            name: menu.name,
            price: menu.price,
            type: menu.type,
          })) || [],
          businessHours: store.businessHours?.map((hours: Hours) => ({
            openHour: hours.openHour,
            openMinute: hours.openMinute,
            closeHour: hours.closeHour,
            closeMinute: hours.closeMinute,
            isNextDay: hours.isNextDay,
            daysOfWeek: hours.daysOfWeek,
          })) || [],
          happyHours: store.happyHours?.map((hours: Hours) => ({
            startHour: hours.startHour,
            startMinute: hours.startMinute,
            endHour: hours.endHour,
            endMinute: hours.endMinute,
            isNextDay: hours.isNextDay,
            daysOfWeek: hours.daysOfWeek,
          })) || [],
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
    } catch (error: unknown) {
      console.error("Error importing stores:", error);
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error occurred",
      });
    }
  }
);
