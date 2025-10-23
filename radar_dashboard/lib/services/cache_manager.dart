// import 'package:flutter/material.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';

// class DashboardCacheManager {
//   static final DashboardCacheManager _instance = DashboardCacheManager._internal();
//   factory DashboardCacheManager() => _instance;
//   DashboardCacheManager._internal();

//   final Map<String, dynamic> _memoryCache = {};
//   final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
//   SharedPreferences? _prefs;

//   Future<void> init() async {
//     _prefs ??= await SharedPreferences.getInstance();
//   }

//   Future<T> getData<T>({
//     required String key,
//     required Future<T> Function() fetchData,
//     Duration cacheDuration = const Duration(hours: 1),
//     bool persist = false,
//     bool forceRefresh = false,
//   }) async {
//     await init();

//     // Memory cache
//     if (!forceRefresh && _memoryCache.containsKey(key)) {
//       return _memoryCache[key] as T;
//     }

//     try {
//       // Disk cache
//       String? jsonString;
//       if (!forceRefresh) {
//         jsonString = persist
//             ? await _secureStorage.read(key: key)
//             : _prefs?.getString(key);
//       }

//       if (jsonString != null) {
//         final decoded = jsonDecode(jsonString);
//         _memoryCache[key] = decoded;
//         return decoded as T;
//       }
//     } catch (e) {
//       debugPrint('[CacheManager] Error decoding cache for key $key: $e');
//     }

//     // Fallback: fetch and save
//     try {
//       final freshData = await fetchData();
//       await saveData(key: key, data: freshData, persist: persist);
//       return freshData;
//     } catch (e) {
//       debugPrint('[CacheManager] Error fetching data: $e');
//       rethrow;
//     }
//   }

//   Future<void> saveData<T>({
//     required String key,
//     required T data,
//     Duration duration = const Duration(hours: 1),
//     bool persist = false,
//   }) async {
//     await init();

//     _memoryCache[key] = data;
//     final encoded = jsonEncode(data);

//     try {
//       if (persist) {
//         await _secureStorage.write(key: key, value: encoded);
//       } else {
//         await _prefs?.setString(key, encoded);
//       }
//     } catch (e) {
//       debugPrint('[CacheManager] Error saving data: $e');
//     }
//   }

//   Future<void> clearCache({bool clearPersistent = false}) async {
//     _memoryCache.clear();
//     await _prefs?.clear();
//     if (clearPersistent) {
//       await _secureStorage.deleteAll();
//     }
//   }
// }
