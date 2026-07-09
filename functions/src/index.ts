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
  type: "like" | "comment";
  actorId: string;
  postId: string;
  title: string;
  body: string;
}): Promise<void> {
  const {recipientId, type, actorId, postId, title, body} = params;

  // 1. Зачувај нотификација во Firestore (за NotificationsScreen во Flutter)
  try {
    await db.collection("notifications").add({
      recipientId,
      type,
      actorId,
      postId,
      read: false,
      createdAt: Timestamp.now(),
    });
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
      data: {type, postId, actorId},
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
 * Ако во `likedBy` е додаден нов userId, испраќа нотификација за лајк.
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

    // Пронајди нов userId додаден во likedBy
    const likedBefore = new Set<string>(before.likedBy ?? []);
    const likedAfter = new Set<string>(after.likedBy ?? []);
    const newLiker = [...likedAfter].find((uid) => !likedBefore.has(uid));
    if (!newLiker) return; // лајк е отстранет, или промената е на друго поле

    const postAuthorId = after.authorId as string;
    const postTitle = after.title as string;
    logger.info("onPostLiked: new like detected", {postId, newLiker});

    // Не испраќај нотификација за лајк на сопствена објава
    if (newLiker === postAuthorId) return;

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
