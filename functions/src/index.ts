import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const createAdminAccount = functions.https.onCall(async (data, context) => {
  // 호출자가 어드민인지 확인
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const callerUid = context.auth.uid;
  const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
  
  if (!callerDoc.exists || callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only administrators can create admin accounts');
  }

  try {
    // 새 사용자 생성
    const userRecord = await admin.auth().createUser({
      email: data.email,
      password: data.password,
      displayName: data.displayName,
    });

    // Custom Claims 설정
    await admin.auth().setCustomUserClaims(userRecord.uid, {
      admin: true
    });

    // Firestore에 사용자 정보 저장
    const userData = {
      email: data.email,
      displayName: data.displayName,
      role: 'admin',
      managedStores: [],
      ownedStores: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: callerUid,
    };

    await admin.firestore().collection('users').doc(userRecord.uid).set(userData);

    return {
      success: true,
      user: {
        uid: userRecord.uid,
        ...userData
      }
    };
  } catch (error) {
    console.error('Error creating admin account:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create admin account');
  }
}); 