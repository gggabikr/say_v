import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

// 어드민 계정 생성
export const createAdminAccount = functions.https.onCall(async (data, context) => {
  // 인증 확인
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      '인증이 필요합니다.'
    );
  }

  // 호출자가 어드민인지 확인
  const callerUid = context.auth.uid;
  const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
  
  if (!callerDoc.exists || callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      '관리자만 새로운 관리자 계정을 생성할 수 있습니다.'
    );
  }

  const { email, password, displayName } = data;

  try {
    // 새 사용자 생성
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
    });

    // Custom Claims 설정
    await admin.auth().setCustomUserClaims(userRecord.uid, {
      admin: true
    });

    // Firestore에 사용자 정보 저장
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      email: email,
      displayName: displayName,
      role: 'admin',
      managedStores: [],
      ownedStores: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: callerUid
    });

    // 로그 기록
    await admin.firestore().collection('adminLogs').add({
      action: 'create_admin_account',
      targetUid: userRecord.uid,
      createdBy: callerUid,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: {
        email: email,
        displayName: displayName
      }
    });

    return {
      success: true,
      user: {
        uid: userRecord.uid,
        email: email,
        displayName: displayName,
        role: 'admin'
      }
    };
  } catch (error) {
    console.error('Error creating admin account:', error);
    throw new functions.https.HttpsError('internal', '관리자 계정 생성에 실패했습니다.');
  }
});

// 스토어 오너 계정 생성
export const createStoreOwnerAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      '인증이 필요합니다.'
    );
  }

  const callerUid = context.auth.uid;
  const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
  
  if (!callerDoc.exists || callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      '관리자만 스토어 오너 계정을 생성할 수 있습니다.'
    );
  }

  const { email, password, displayName, storeIds } = data;

  try {
    // 새 사용자 생성
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
    });

    // Custom Claims 설정
    await admin.auth().setCustomUserClaims(userRecord.uid, {
      storeOwner: true
    });

    // Firestore에 사용자 정보 저장
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      email: email,
      displayName: displayName,
      role: 'owner',
      managedStores: [],
      ownedStores: storeIds,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: callerUid
    });

    // 각 스토어 문서에 오너 정보 업데이트
    for (const storeId of storeIds) {
      await admin.firestore().collection('stores').doc(storeId).update({
        ownerId: userRecord.uid
      });
    }

    return {
      success: true,
      user: {
        uid: userRecord.uid,
        email: email,
        displayName: displayName,
        role: 'owner',
        ownedStores: storeIds
      }
    };
  } catch (error) {
    console.error('Error creating store owner account:', error);
    throw new functions.https.HttpsError('internal', '스토어 오너 계정 생성에 실패했습니다.');
  }
});

// 스토어 매니저 계정 생성
export const createStoreManagerAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      '인증이 필요합니다.'
    );
  }

  const callerUid = context.auth.uid;
  const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
  
  if (!callerDoc.exists) {
    throw new functions.https.HttpsError(
      'permission-denied',
      '권한이 없습니다.'
    );
  }

  const callerRole = callerDoc.data()?.role;
  if (callerRole !== 'admin' && callerRole !== 'owner') {
    throw new functions.https.HttpsError(
      'permission-denied',
      '관리자 또는 스토어 오너만 매니저 계정을 생성할 수 있습니다.'
    );
  }

  const { email, password, displayName, storeIds } = data;

  // 스토어 오너의 경우 자신의 스토어에 대해서만 매니저 생성 가능
  if (callerRole === 'owner') {
    const ownedStores = callerDoc.data()?.ownedStores || [];
    if (!storeIds.every((id: string) => ownedStores.includes(id))) {
      throw new functions.https.HttpsError(
        'permission-denied',
        '스토어 오너는 자신이 소유한 스토어의 매니저만 생성할 수 있습니다.'
      );
    }
  }

  try {
    // 새 사용자 생성
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: displayName,
    });

    // Custom Claims 설정
    await admin.auth().setCustomUserClaims(userRecord.uid, {
      storeManager: true
    });

    // Firestore에 사용자 정보 저장
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      email: email,
      displayName: displayName,
      role: 'manager',
      managedStores: storeIds,
      ownedStores: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: callerUid
    });

    // 각 스토어 문서에 매니저 정보 추가
    for (const storeId of storeIds) {
      await admin.firestore().collection('stores').doc(storeId).update({
        managers: admin.firestore.FieldValue.arrayUnion(userRecord.uid)
      });
    }

    return {
      success: true,
      user: {
        uid: userRecord.uid,
        email: email,
        displayName: displayName,
        role: 'manager',
        managedStores: storeIds
      }
    };
  } catch (error) {
    console.error('Error creating store manager account:', error);
    throw new functions.https.HttpsError('internal', '스토어 매니저 계정 생성에 실패했습니다.');
  }
});