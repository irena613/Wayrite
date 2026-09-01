import {initializeApp} from "firebase-admin/app";
import {
  FieldValue,
  getFirestore,
  Timestamp,
} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {setGlobalOptions} from "firebase-functions";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

setGlobalOptions({maxInstances: 10, region: "europe-west1"});

// ---------------------------------------------------------------------------
// TASK 2 — FCM Token Management
// ---------------------------------------------------------------------------

/**
 * Регистрира FCM токен за автентициран корисник.
 * Повикано од Flutter по login/register или при освежување на токенот.
 */
export const registerFcmToken = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Мора да сте најавени.");
  }

  const data = request.data as Record<string, unknown>;
  const token = data?.token;
  if (!token || typeof token !== "string" || token.trim() === "") {
    throw new HttpsError("invalid-argument", "FCM token е задолжителен.");
  }

  logger.info("registerFcmToken: started", {
    uid,
    tokenStart: token.slice(0, 15),
  });

  try {
    await db.collection("users").doc(uid).update({
      fcmTokens: FieldValue.arrayUnion(token.trim()),
    });
    logger.info("registerFcmToken: success", {uid});
    return {success: true};
  } catch (e) {
    logger.error("registerFcmToken: failed", {
      uid,
      error: (e as Error).message,
    });
    throw new HttpsError("internal", "Неуспешна регистрација на токенот.");
  }
});

/**
 * Отстранува FCM токен за автентициран корисник.
 * Повикано од Flutter пред одјава или при освежување на токенот.
 */
export const unregisterFcmToken = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Мора да сте најавени.");
  }

  const data = request.data as Record<string, unknown>;
  const token = data?.token;
  if (!token || typeof token !== "string" || token.trim() === "") {
    throw new HttpsError("invalid-argument", "FCM token е задолжителен.");
  }

  logger.info("unregisterFcmToken: started", {uid});

  try {
    await db.collection("users").doc(uid).update({
      fcmTokens: FieldValue.arrayRemove(token.trim()),
    });
    logger.info("unregisterFcmToken: success", {uid});
    return {success: true};
  } catch (e) {
    logger.error("unregisterFcmToken: failed", {
      uid,
      error: (e as Error).message,
    });
    throw new HttpsError("internal", "Неуспешно бришење на токенот.");
  }
});

// ---------------------------------------------------------------------------
// TASK 1 — Push Notification Helper (called by triggers below)
// ---------------------------------------------------------------------------

async function sendPushNotification(params: {
  recipientId: string;
  type: "like" | "comment" | "friendRequest" | "friendAccept";
  actorId: string;
  postId?: string;
  title: string;
  body: string;
  // Deterministic doc id (e.g. `like_{postId}_{actorId}`) so re-liking after
  // an unlike updates the same notification instead of piling up a new one
  // each time. Omit for one-shot notifications (comments, friend events).
  notificationId?: string;
}): Promise<void> {
  const {recipientId, type, actorId, postId, title, body, notificationId} =
    params;

  // 1. Зачувај нотификација во Firestore (за NotificationsScreen во Flutter)
  try {
    const data = {
      recipientId,
      type,
      actorId,
      ...(postId ? {postId} : {}),
      read: false,
      createdAt: Timestamp.now(),
    };
    if (notificationId) {
      await db.collection("notifications").doc(notificationId).set(data);
    } else {
      await db.collection("notifications").add(data);
    }
    logger.info("sendPush: notification written", {recipientId, type, postId});
  } catch (e) {
    logger.error("sendPush: Firestore write failed", {
      recipientId,
      error: (e as Error).message,
    });
  }

  // 2. Вчитај FCM токени на примателот
  let tokens: string[] = [];
  try {
    const userDoc = await db.collection("users").doc(recipientId).get();
    if (!userDoc.exists) return;
    tokens = (userDoc.data()?.fcmTokens as string[]) ?? [];
    if (tokens.length === 0) {
      logger.info("sendPush: no tokens, skip FCM", {recipientId});
      return;
    }
  } catch (e) {
    logger.warn("sendPush: failed to fetch tokens", {
      recipientId,
      error: (e as Error).message,
    });
    return;
  }

  // 3. Испрати FCM push до сите уреди на корисникот
  try {
    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: {title, body},
      data: {type, actorId, ...(postId ? {postId} : {})},
    });
    logger.info("sendPush: FCM sent", {
      recipientId,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });

    // 4. Отстрани токени кои FCM ги пријавил како невалидни
    const invalid: string[] = [];
    response.responses.forEach((r, i) => {
      const code = r.error?.code ?? "";
      if (
        !r.success &&
        (code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered")
      ) {
        invalid.push(tokens[i]);
      }
    });
    if (invalid.length > 0) {
      await db.collection("users").doc(recipientId).update({
        fcmTokens: FieldValue.arrayRemove(...invalid),
      });
      logger.warn("sendPush: removed invalid tokens", {
        recipientId,
        count: invalid.length,
      });
    }
  } catch (e) {
    logger.error("sendPush: FCM send failed", {
      recipientId,
      error: (e as Error).message,
    });
  }
}

// ---------------------------------------------------------------------------
// TASK 5 — Firestore Triggers: Comments & Reactions
// ---------------------------------------------------------------------------

/**
 * Активира се кога Flutter ќе запише нов коментар-документ во
 * posts/{postId}/comments/{commentId}.
 * Испраќа нотификација до авторот на објавата.
 */
export const onCommentCreated = onDocumentCreated(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const {postId, commentId} = event.params;
    const commentData = event.data?.data();

    if (!commentData) {
      logger.warn("onCommentCreated: no data", {postId, commentId});
      return;
    }

    const actorId = commentData.authorId as string;
    logger.info("onCommentCreated: started", {postId, commentId, actorId});

    // Вчитај ја објавата за да го добиеш авторот и насловот
    let postAuthorId: string;
    let postTitle: string;
    try {
      const postDoc = await db.collection("posts").doc(postId).get();
      if (!postDoc.exists) {
        logger.warn("onCommentCreated: post not found", {postId});
        return;
      }
      const postData = postDoc.data() as Record<string, unknown>;
      postAuthorId = postData.authorId as string;
      postTitle = postData.title as string;
    } catch (e) {
      logger.error("onCommentCreated: failed to fetch post", {
        postId,
        error: (e as Error).message,
      });
      return;
    }

    // Не испраќај нотификација ако авторот коментира на своја објава
    if (actorId === postAuthorId) {
      logger.info("onCommentCreated: actor is author, skipping", {postId});
      return;
    }

    // Вчитај го името на коментаторот
    let actorName = "Некој";
    try {
      const actorDoc = await db.collection("users").doc(actorId).get();
      actorName = (actorDoc.data()?.name as string) ?? "Некој";
    } catch (_) {
      // actor name is best-effort; fallback already set above
    }

    await sendPushNotification({
      recipientId: postAuthorId,
      type: "comment",
      actorId,
      postId,
      title: actorName,
      body: `коментираше на „${postTitle}"`,
    });

    logger.info("onCommentCreated: done", {postId, commentId});
  }
);

/**
 * Активира се при секоја промена на post-документот.
 * Ако во `likedBy` е додаден нов userId, испраќа (или ажурира) нотификација
 * за лајк со детерминистички doc id `like_{postId}_{actorId}` — повторен лајк
 * од истиот корисник го ажурира истиот документ наместо да создава нов.
 * Ако userId е отстранет (unlike), тој ист документ се брише, за
 * нотификацијата веднаш да исчезне од примачот.
 * Промени на други полиња (commentIds, title...) се игнорираат.
 */
export const onPostLiked = onDocumentUpdated(
  "posts/{postId}",
  async (event) => {
    const {postId} = event.params;
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) {
      logger.warn("onPostLiked: missing snapshot data", {postId});
      return;
    }

    const likedBefore = new Set<string>(before.likedBy ?? []);
    const likedAfter = new Set<string>(after.likedBy ?? []);
    const newLiker = [...likedAfter].find((uid) => !likedBefore.has(uid));
    const removedLiker = [...likedBefore].find((uid) => !likedAfter.has(uid));
    if (!newLiker && !removedLiker) return; // промената е на друго поле

    const postAuthorId = after.authorId as string;
    const postTitle = after.title as string;

    if (removedLiker && removedLiker !== postAuthorId) {
      logger.info("onPostLiked: like removed, deleting notification", {
        postId,
        removedLiker,
      });
      await db
        .collection("notifications")
        .doc(`like_${postId}_${removedLiker}`)
        .delete()
        .catch((e) => {
          logger.warn("onPostLiked: notification delete failed", {
            postId,
            removedLiker,
            error: (e as Error).message,
          });
        });
      return;
    }

    if (!newLiker || newLiker === postAuthorId) return;
    logger.info("onPostLiked: new like detected", {postId, newLiker});

    // Вчитај го името на корисникот кој лајкувал
    let actorName = "Некој";
    try {
      const actorDoc = await db.collection("users").doc(newLiker).get();
      actorName = (actorDoc.data()?.name as string) ?? "Некој";
    } catch (_) {
      // actor name is best-effort; fallback already set above
    }

    await sendPushNotification({
      recipientId: postAuthorId,
      type: "like",
      actorId: newLiker,
      postId,
      title: actorName,
      body: `му се допадна „${postTitle}"`,
      notificationId: `like_${postId}_${newLiker}`,
    });

    logger.info("onPostLiked: done", {postId, newLiker});
  }
);

// ---------------------------------------------------------------------------
// TASK 3 — Server-side Post Validation
// ---------------------------------------------------------------------------

/**
 * Валидира и креира нова објава на серверска страна.
 * Flutter ја повикува наместо директно да пишува во Firestore.
 * Ја прифаќа истата postId генерирана од Flutter за конзистентност.
 */
export const createPostValidated = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Мора да сте најавени.");
  }

  const data = request.data as Record<string, unknown>;
  const {type, title, description, startDate, endDate, postId} = data;

  logger.info("createPostValidated: started", {uid, type});

  // Тип: мора да биде 'achievement' или 'quit'
  if (!type || (type !== "achievement" && type !== "quit")) {
    throw new HttpsError(
      "invalid-argument",
      "Типот мора да биде 'achievement' или 'quit'.",
    );
  }

  // Наслов: 1–100 знаци
  if (!title || typeof title !== "string" || title.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Насловот е задолжителен.");
  }
  if (title.trim().length > 100) {
    throw new HttpsError(
      "invalid-argument",
      "Насловот е предолг (максимум 100 знаци).",
    );
  }

  // Опис: максимум 500 знаци
  if (typeof description === "string" && description.trim().length > 500) {
    throw new HttpsError(
      "invalid-argument",
      "Описот е предолг (максимум 500 знаци).",
    );
  }

  // Почетен датум: задолжителен, валиден датум
  if (!startDate || typeof startDate !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "Почетниот датум е задолжителен.",
    );
  }
  const start = new Date(startDate);
  if (isNaN(start.getTime())) {
    throw new HttpsError("invalid-argument", "Невалиден почетен датум.");
  }

  // Краен датум: ако е наведен, мора да биде по почетниот
  if (endDate !== undefined && endDate !== null) {
    if (typeof endDate !== "string") {
      throw new HttpsError("invalid-argument", "Невалиден краен датум.");
    }
    const end = new Date(endDate);
    if (isNaN(end.getTime()) || end < start) {
      throw new HttpsError(
        "invalid-argument",
        "Крајниот датум мора да биде по почетниот.",
      );
    }
  }

  // Зачувај во Firestore — користи postId пратен од Flutter ако постои
  const postRef = typeof postId === "string" && postId.trim() ?
    db.collection("posts").doc(postId.trim()) :
    db.collection("posts").doc();

  const postData: Record<string, unknown> = {
    authorId: uid,
    type,
    title: (title as string).trim(),
    description: typeof description === "string" ? description.trim() : "",
    startDate: Timestamp.fromDate(start),
    createdAt: Timestamp.now(),
    likedBy: [],
    commentIds: [],
  };
  if (endDate) {
    postData.endDate = Timestamp.fromDate(new Date(endDate as string));
  }

  try {
    await postRef.set(postData);
    logger.info("createPostValidated: success", {uid, postId: postRef.id});
    return {postId: postRef.id};
  } catch (e) {
    logger.error("createPostValidated: Firestore write failed", {
      uid,
      error: (e as Error).message,
    });
    throw new HttpsError("internal", "Грешка при зачувување на објавата.");
  }
});

// ---------------------------------------------------------------------------
// TASK 4 — Streak & Duration Calculation
// ---------------------------------------------------------------------------

/**
 * Се извршува секој ден во полноќ и го ажурира `currentStreakDays`
 * за сите активни Quit објави (оние без краен датум).
 */
export const updateAllStreaks = onSchedule("0 0 * * *", async () => {
  logger.info("updateAllStreaks: started");

  const snapshot = await db.collection("posts")
    .where("type", "==", "quit")
    .get();

  const updates: Promise<FirebaseFirestore.WriteResult>[] = [];
  const now = Date.now();

  for (const doc of snapshot.docs) {
    const d = doc.data();
    if (d.endDate) continue; // objava already ended — skip

    const start = (d.startDate as Timestamp).toDate();
    const streakDays = Math.max(
      0,
      Math.floor((now - start.getTime()) / (1000 * 60 * 60 * 24)),
    );

    if (d.currentStreakDays === streakDays) continue; // no change needed

    updates.push(doc.ref.update({currentStreakDays: streakDays}));
  }

  await Promise.all(updates);
  logger.info("updateAllStreaks: done", {
    total: snapshot.size,
    updated: updates.length,
  });
});

/**
 * Се активира при секоја промена на post-документот.
 * Ако е Quit objava и датумите се сменети, го рекалкулира `currentStreakDays`.
 * Проверката за непроменета вредност го спречува бесконечниот циклус.
 */
export const recalcStreak = onDocumentUpdated(
  "posts/{postId}",
  async (event) => {
    const {postId} = event.params;
    const after = event.data?.after.data();
    const afterRef = event.data?.after.ref;

    if (!after || !afterRef || after.type !== "quit") return;

    const start = (after.startDate as Timestamp).toDate();
    const endTs = after.endDate as Timestamp | undefined;
    const end = endTs ? endTs.toDate() : new Date();
    const streakDays = Math.max(
      0,
      Math.floor((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)),
    );

    // Не ажурирај ако вредноста е иста — спречува повторно активирање
    if (after.currentStreakDays === streakDays) return;

    logger.info("recalcStreak: updating", {postId, streakDays});
    try {
      await afterRef.update({currentStreakDays: streakDays});
      logger.info("recalcStreak: done", {postId, streakDays});
    } catch (e) {
      logger.error("recalcStreak: update failed", {
        postId,
        error: (e as Error).message,
      });
    }
  }
);

// ---------------------------------------------------------------------------
// TASK 6 — Friend Requests & Friendships
// ---------------------------------------------------------------------------
//
// friendRequests/{fromUserId}_{toUserId} — pending requests only; the doc is
// deleted on accept/decline/cancel. Accepting/unfriending touches both
// users' `friendIds` array, so those mutations run here (Admin SDK bypasses
// Firestore rules) instead of as direct client writes.

function friendRequestDocId(fromUserId: string, toUserId: string): string {
  return `${fromUserId}_${toUserId}`;
}

/**
 * Испраќа барање за пријателство. Атомски проверува дека не постои веќе
 * пријателство или барање (во која било насока) помеѓу двата корисника.
 */
export const sendFriendRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Мора да сте најавени.");
  }

  const data = request.data as Record<string, unknown>;
  const toUserId = data?.toUserId;
  if (!toUserId || typeof toUserId !== "string" || toUserId.trim() === "") {
    throw new HttpsError("invalid-argument", "Мора да се наведе корисник.");
  }
  if (toUserId === uid) {
    throw new HttpsError(
      "invalid-argument",
      "Не можете да си испратите барање сами на себе."
    );
  }

  logger.info("sendFriendRequest: started", {uid, toUserId});

  const fromRef = db.collection("users").doc(uid);
  const toRef = db.collection("users").doc(toUserId);
  const forwardRef = db.collection("friendRequests")
    .doc(friendRequestDocId(uid, toUserId));
  const reverseRef = db.collection("friendRequests")
    .doc(friendRequestDocId(toUserId, uid));

  try {
    await db.runTransaction(async (tx) => {
      const [fromSnap, toSnap, forwardSnap, reverseSnap] = await Promise.all([
        tx.get(fromRef),
        tx.get(toRef),
        tx.get(forwardRef),
        tx.get(reverseRef),
      ]);

      if (!toSnap.exists) {
        throw new HttpsError("not-found", "Корисникот не постои.");
      }
      const friendIds = (fromSnap.data()?.friendIds as string[]) ?? [];
      if (friendIds.includes(toUserId)) {
        throw new HttpsError("already-exists", "Веќе сте пријатели.");
      }
      if (forwardSnap.exists) {
        throw new HttpsError("already-exists", "Барањето е веќе испратено.");
      }
      if (reverseSnap.exists) {
        throw new HttpsError(
          "already-exists",
          "Тој корисник веќе ви испратил барање — прифатете го наместо тоа."
        );
      }

      tx.set(forwardRef, {
        fromUserId: uid,
        toUserId,
        createdAt: Timestamp.now(),
      });
    });
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    logger.error("sendFriendRequest: failed", {
      uid,
      toUserId,
      error: (e as Error).message,
    });
    throw new HttpsError("internal", "Неуспешно испраќање на барањето.");
  }

  let actorName = "Некој";
  try {
    const fromDoc = await fromRef.get();
    actorName = (fromDoc.data()?.name as string) ?? "Некој";
  } catch (_) {
    // actor name is best-effort
  }

  await sendPushNotification({
    recipientId: toUserId,
    type: "friendRequest",
    actorId: uid,
    title: actorName,
    body: "ви испрати барање за пријателство",
  });

  logger.info("sendFriendRequest: success", {uid, toUserId});
  return {success: true};
});

/**
 * Откажува барање што самиот корисник го испратил.
 */
export const cancelFriendRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Мора да сте најавени.");
  }
  const data = request.data as Record<string, unknown>;
  const toUserId = data?.toUserId;
  if (!toUserId || typeof toUserId !== "string" || toUserId.trim() === "") {
    throw new HttpsError("invalid-argument", "Мора да се наведе корисник.");
  }

  const requestRef = db.collection("friendRequests")
    .doc(friendRequestDocId(uid, toUserId));
  try {
    const snap = await requestRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Барањето веќе не постои.");
    }
    await requestRef.delete();
    logger.info("cancelFriendRequest: success", {uid, toUserId});
    return {success: true};
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    logger.error("cancelFriendRequest: failed", {
      uid,
      toUserId,
      error: (e as Error).message,
    });
    throw new HttpsError("internal", "Неуспешно откажување на барањето.");
  }
});

/**
 * Одбива барање за пријателство упатено до тековниот корисник.
 */
export const declineFriendRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Мора да сте најавени.");
  }
  const data = request.data as Record<string, unknown>;
  const fromUserId = data?.fromUserId;
  if (
    !fromUserId ||
    typeof fromUserId !== "string" ||
    fromUserId.trim() === ""
  ) {
    throw new HttpsError("invalid-argument", "Мора да се наведе корисник.");
  }

  const requestRef = db.collection("friendRequests")
    .doc(friendRequestDocId(fromUserId, uid));
  try {
    const snap = await requestRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Барањето веќе не постои.");
    }
    await requestRef.delete();
    logger.info("declineFriendRequest: success", {uid, fromUserId});
    return {success: true};
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    logger.error("declineFriendRequest: failed", {
      uid,
      fromUserId,
      error: (e as Error).message,
    });
    throw new HttpsError("internal", "Неуспешно одбивање на барањето.");
  }
});

/**
 * Прифаќа барање за пријателство — атомски ги ажурира `friendIds` на двата
 * корисника и го брише барањето.
 */
export const acceptFriendRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Мора да сте најавени.");
  }
  const data = request.data as Record<string, unknown>;
  const fromUserId = data?.fromUserId;
  if (
    !fromUserId ||
    typeof fromUserId !== "string" ||
    fromUserId.trim() === ""
  ) {
    throw new HttpsError("invalid-argument", "Мора да се наведе корисник.");
  }

  logger.info("acceptFriendRequest: started", {uid, fromUserId});

  const requestRef = db.collection("friendRequests")
    .doc(friendRequestDocId(fromUserId, uid));
  const fromUserRef = db.collection("users").doc(fromUserId);
  const toUserRef = db.collection("users").doc(uid);

  try {
    await db.runTransaction(async (tx) => {
      const reqSnap = await tx.get(requestRef);
      if (!reqSnap.exists) {
        throw new HttpsError("not-found", "Барањето веќе не постои.");
      }
      tx.update(fromUserRef, {friendIds: FieldValue.arrayUnion(uid)});
      tx.update(toUserRef, {friendIds: FieldValue.arrayUnion(fromUserId)});
      tx.delete(requestRef);
    });
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    logger.error("acceptFriendRequest: failed", {
      uid,
      fromUserId,
      error: (e as Error).message,
    });
    throw new HttpsError("internal", "Неуспешно прифаќање на барањето.");
  }

  let actorName = "Некој";
  try {
    const toDoc = await toUserRef.get();
    actorName = (toDoc.data()?.name as string) ?? "Некој";
  } catch (_) {
    // actor name is best-effort
  }

  await sendPushNotification({
    recipientId: fromUserId,
    type: "friendAccept",
    actorId: uid,
    title: actorName,
    body: "го прифати вашето барање за пријателство",
  });

  logger.info("acceptFriendRequest: success", {uid, fromUserId});
  return {success: true};
});

/**
 * Раскинува постоечко пријателство — отстранува секој корисник од
 * `friendIds` листата на другиот.
 */
export const unfriend = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Мора да сте најавени.");
  }
  const data = request.data as Record<string, unknown>;
  const otherUserId = data?.otherUserId;
  if (
    !otherUserId ||
    typeof otherUserId !== "string" ||
    otherUserId.trim() === ""
  ) {
    throw new HttpsError("invalid-argument", "Мора да се наведе корисник.");
  }

  logger.info("unfriend: started", {uid, otherUserId});

  const batch = db.batch();
  batch.update(db.collection("users").doc(uid), {
    friendIds: FieldValue.arrayRemove(otherUserId),
  });
  batch.update(db.collection("users").doc(otherUserId), {
    friendIds: FieldValue.arrayRemove(uid),
  });

  try {
    await batch.commit();
    logger.info("unfriend: success", {uid, otherUserId});
    return {success: true};
  } catch (e) {
    logger.error("unfriend: failed", {
      uid,
      otherUserId,
      error: (e as Error).message,
    });
    throw new HttpsError("internal", "Неуспешно бришење на пријателството.");
  }
});
