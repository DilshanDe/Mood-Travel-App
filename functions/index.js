const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Trigger when new places are added for training
 */
exports.checkModelRetraining = functions.firestore
    .document("pending_training_places/{placeId}")
    .onCreate(async (snap, _context) => {
      try {
        console.log(" New place added:", snap.data().name);

        // Count pending places
        const pendingPlaces = await db.collection("pending_training_places")
            .where("trained", "==", false)
            .get();

        const pendingCount = pendingPlaces.size;
        console.log(` Total pending places: ${pendingCount}`);

        // Trigger retraining if threshold reached
        const RETRAIN_THRESHOLD = 1;
        if (pendingCount >= RETRAIN_THRESHOLD) {
          console.log(" Triggering model retraining...");
          await triggerModelRetraining(pendingPlaces.docs);
        }

        return null;
      } catch (error) {
        console.error(" Error in checkModelRetraining:", error);
        return null;
      }
    });

/**
 * Manual retrain function
 */
exports.manualRetrain = functions.https.onCall(async (_data, _context) => {
  try {
    console.log(" Manual retraining triggered");

    const pendingPlaces = await db.collection("pending_training_places")
        .where("trained", "==", false)
        .get();

    if (pendingPlaces.empty) {
      return {success: false, message: "No pending places to train"};
    }

    await triggerModelRetraining(pendingPlaces.docs);

    return {
      success: true,
      message: `Model retrained with ${pendingPlaces.size} new places`,
    };
  } catch (error) {
    console.error(" Manual retrain error:", error);
    throw new functions.https.HttpsError("internal", "Retraining failed");
  }
});

/**
 * Core retraining function
 * @param {Array} pendingDocs - Array of pending document references
 */
async function triggerModelRetraining(pendingDocs) {
  try {
    console.log("🧠 Starting model retraining process...");

    // 1. Prepare training data
    const trainingData = await prepareTrainingData(pendingDocs);
    console.log(`📚 Prepared ${trainingData.length} training samples`);

    // 2. Simulate model training (in production, use actual ML pipeline)
    await simulateModelTraining(trainingData);

    // 3. Mark places as trained
    await markPlacesAsTrained(pendingDocs);

    // 4. Notify clients about model update
    await notifyClientsModelUpdated();

    console.log("✅ Model retraining completed successfully!");
  } catch (error) {
    console.error("❌ Model retraining failed:", error);
    throw error;
  }
}

/**
 * Prepare training data from pending places
 * @param {Array} pendingDocs - Array of pending document references
 * @return {Array} Training data array
 */
async function prepareTrainingData(pendingDocs) {
  const trainingData = [];

  for (const doc of pendingDocs) {
    const placeData = doc.data();

    // Skip unverified places
    if (placeData.verified === false) {
      continue;
    }

    try {
      // Convert place data to training format
      const features = extractFeaturesFromPlace(placeData);
      const label = mapPlaceTypeToLabel(placeData.type);

      trainingData.push({
        features: features,
        label: label,
        placeData: placeData,
      });
    } catch (error) {
      console.error(`❌ Error processing place ${placeData.name}:`, error);
    }
  }

  return trainingData;
}

/**
 * Extract features from place data
 * @param {Object} placeData - Place data object
 * @return {Array} Features array
 */
function extractFeaturesFromPlace(placeData) {
  const features = [];

  // Numerical features (matching your ML model input)
  features.push(Math.log1p(placeData.cost || 100)); // log-transformed budget
  features.push(placeData.duration || 1);
  features.push(2); // default group_size
  features.push(3); // default travel_frequency
  features.push(10); // default liked_posts
  features.push(5); // default shared_posts

  // Activity scores based on place type and activities
  const activityScores = analyzeActivitiesAndCaption(
      placeData.activities || [],
      placeData.caption || "",
  );
  features.push(...activityScores);

  // One-hot encoded features
  features.push(...encodeSeason("summer")); // default season
  features.push(...encodePersonality(inferPersonalityFromType(placeData.type)));
  features.push(...encodeAgeGroup("adult")); // default age group

  return features;
}

/**
 * Analyze activities and caption for activity scores
 * @param {Array} activities - Activities array
 * @param {string} caption - Caption string
 * @return {Array} Activity scores array
 */
function analyzeActivitiesAndCaption(activities = [], caption = "") {
  const activityKeywords = {
    adventure: ["hiking", "climbing", "trekking", "adventure", "explore"],
    cultural: ["temple", "museum", "cultural", "heritage", "traditional"],
    relaxation: ["relax", "peaceful", "calm", "spa", "quiet"],
    food: ["food", "restaurant", "taste", "delicious", "cuisine"],
    nature: ["nature", "forest", "park", "garden", "waterfall"],
    urban: ["city", "urban", "shopping", "modern", "downtown"],
  };

  const text = (activities.join(" ") + " " + caption).toLowerCase();
  const scores = {};

  for (const [category, keywords] of Object.entries(activityKeywords)) {
    scores[category] = keywords.reduce((score, keyword) =>
      score + (text.includes(keyword) ? 1 : 0), 0) / keywords.length;
  }

  return [
    scores.adventure || 0.5,
    scores.cultural || 0.5,
    scores.relaxation || 0.5,
    scores.food || 0.5,
    scores.nature || 0.5,
    scores.urban || 0.5,
  ];
}

/**
 * Encode season to one-hot array
 * @param {string} season - Season name
 * @return {Array} One-hot encoded array
 */
function encodeSeason(season) {
  const seasons = ["spring", "summer", "autumn", "winter"];
  return seasons.map((s) => (s === season ? 1 : 0));
}

/**
 * Encode personality to one-hot array
 * @param {string} personality - Personality type
 * @return {Array} One-hot encoded array
 */
function encodePersonality(personality) {
  const personalities = ["adventurous", "cultural", "relaxed", "social"];
  return personalities.map((p) => (p === personality ? 1 : 0));
}

/**
 * Encode age group to one-hot array
 * @param {string} ageGroup - Age group
 * @return {Array} One-hot encoded array
 */
function encodeAgeGroup(ageGroup) {
  const ageGroups = ["teen", "young_adult", "adult", "middle_aged", "senior"];
  return ageGroups.map((ag) => (ag === ageGroup ? 1 : 0));
}

/**
 * Infer personality from place type
 * @param {string} type - Place type
 * @return {string} Personality type
 */
function inferPersonalityFromType(type) {
  const mapping = {
    "adventure": "adventurous",
    "cultural": "cultural",
    "relaxation": "relaxed",
    "food_tourism": "social",
    "nature": "adventurous",
    "urban": "social",
    "beach": "relaxed",
    "mountain": "adventurous",
    "historical": "cultural",
    "wildlife": "adventurous",
  };
  return mapping[type] || "cultural";
}

/**
 * Map place type to numerical label
 * @param {string} type - Place type
 * @return {number} Numerical label
 */
function mapPlaceTypeToLabel(type) {
  const typeLabels = {
    "adventure": 0,
    "cultural": 1,
    "relaxation": 2,
    "food_tourism": 3,
    "nature": 4,
    "urban": 5,
    "beach": 6,
    "mountain": 7,
    "historical": 8,
    "wildlife": 9,
  };
  return typeLabels[type] || 1; // default to cultural
}

/**
 * Simulate model training
 * @param {Array} trainingData - Training data array
 */
async function simulateModelTraining(trainingData) {
  console.log("🏃 Simulating model training...");

  // In production, you would:
  // 1. Send training data to your ML training service
  // 2. Retrain the model with new data
  // 3. Save the updated model to storage
  // 4. Update model metadata

  // For now, just simulate the process
  await new Promise((resolve) => setTimeout(resolve, 2000));

  // Update model metadata in Firestore
  await db.collection("ml_models").doc("travel_recommendation").set({
    version: Date.now(),
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    totalPlaces: await getTotalPlacesCount(),
    trainingDataSize: trainingData.length,
    status: "updated",
  });

  console.log("🧠 Model training simulation completed");
}

/**
 * Mark places as trained
 * @param {Array} pendingDocs - Array of pending document references
 */
async function markPlacesAsTrained(pendingDocs) {
  const batch = db.batch();

  for (const doc of pendingDocs) {
    batch.update(doc.ref, {
      trained: true,
      trainedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  console.log(`✅ Marked ${pendingDocs.length} places as trained`);
}

/**
 * Notify clients about model update
 */
async function notifyClientsModelUpdated() {
  try {
    console.log("📢 Notifying clients about model update...");

    // Update app config to trigger model reload
    await db.collection("app_config").doc("ml_model").set({
      shouldReload: true,
      lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
      version: Date.now(),
    });

    console.log("✅ Clients notified successfully");
  } catch (error) {
    console.error("❌ Error notifying clients:", error);
  }
}

/**
 * Get total places count
 * @return {number} Total places count
 */
async function getTotalPlacesCount() {
  try {
    const allPlaces = await db.collection("pending_training_places").get();
    return allPlaces.size;
  } catch (error) {
    console.error("❌ Error getting total places count:", error);
    return 0;
  }
}

/**
 * Get model training statistics
 */
exports.getModelStats = functions.https.onCall(async (_data, _context) => {
  try {
    const [totalPlaces, pendingPlaces, modelInfo] = await Promise.all([
      db.collection("pending_training_places").get(),
      db.collection("pending_training_places")
          .where("trained", "==", false).get(),
      db.collection("ml_models").doc("travel_recommendation").get(),
    ]);

    return {
      totalPlaces: totalPlaces.size,
      pendingPlaces: pendingPlaces.size,
      trainedPlaces: totalPlaces.size - pendingPlaces.size,
      lastModelUpdate: modelInfo.exists ?
        modelInfo.data().lastUpdated : null,
      modelVersion: modelInfo.exists ? modelInfo.data().version : null,
      needsRetraining: pendingPlaces.size >= 10,
    };
  } catch (error) {
    console.error("❌ Error getting model stats:", error);
    throw new functions.https.HttpsError("internal", "Failed to get stats");
  }
});

/**
 * Verify a place (admin function)
 */
exports.verifyPlace = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be authenticated",
    );
  }

  const {placeId, approved, reason} = data;

  try {
    await db.collection("pending_training_places").doc(placeId).update({
      verified: approved,
      verificationReason: reason || "",
      verifiedBy: context.auth.uid,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: approved ? "Place approved" : "Place rejected",
    };
  } catch (error) {
    console.error("❌ Error verifying place:", error);
    throw new functions.https.HttpsError("internal", "Verification failed");
  }
});

/**
 * Get model download URL (for mobile app updates)
 */
exports.getModelDownloadUrl = functions.https.onCall(
    async (_data, _context) => {
      try {
        // In production, you would generate a signed URL for model download
        // For now, return a placeholder response

        const modelInfo = await db.collection("ml_models")
            .doc("travel_recommendation").get();

        return {
          downloadUrl: "https://your-storage-bucket.googleapis.com/" +
            "ml_models/travel_model.tflite",
          version: modelInfo.exists ? modelInfo.data().version : Date.now(),
          lastUpdated: modelInfo.exists ?
            modelInfo.data().lastUpdated : null,
          size: 1024 * 1024, // 1MB placeholder
        };
      } catch (error) {
        console.error("❌ Error generating download URL:", error);
        throw new functions.https.HttpsError(
            "internal",
            "Failed to generate URL",
        );
      }
    });

/**
 * Scheduled function to auto-verify places (optional)
 */
exports.scheduledPlaceVerification = functions.pubsub
    .schedule("0 2 * * *") // Run at 2 AM daily
    .timeZone("Asia/Colombo")
    .onRun(async (_context) => {
      try {
        console.log("🕐 Running scheduled place verification...");

        // Auto-verify places that meet certain criteria
        const pendingPlaces = await db.collection("pending_training_places")
            .where("verified", "==", false)
            .where("addedAt", "<=",
                Date.now() - (24 * 60 * 60 * 1000)) // 24 hours old
            .limit(5)
            .get();

        const batch = db.batch();
        let verifiedCount = 0;

        pendingPlaces.docs.forEach((doc) => {
          const placeData = doc.data();

          // Simple auto-verification criteria
          if (placeData.cost > 10 &&
            placeData.activities &&
            placeData.activities.length > 0 &&
            placeData.caption &&
            placeData.caption.length > 20) {
            batch.update(doc.ref, {
              verified: true,
              verificationReason: "Auto-verified by system",
              verifiedBy: "system",
              verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            verifiedCount++;
          }
        });

        if (verifiedCount > 0) {
          await batch.commit();
          console.log(`✅ Auto-verified ${verifiedCount} places`);
        }

        return null;
      } catch (error) {
        console.error("❌ Scheduled verification failed:", error);
        return null;
      }
    });
