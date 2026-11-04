import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic/models/user_model.dart';

void main() {
  group('UserModel Serialization & Deserialization Tests', () {
    test('Constructs UserModel with all fields', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user_123',
        name: 'Rahul Sharma',
        displayName: 'Rahul Sharma',
        username: 'rahul_sharma',
        email: 'rahul@example.com',
        phone: '+919876543210',
        photoURL: 'https://storage.googleapis.com/avatar.jpg',
        profilePhoto: 'https://storage.googleapis.com/avatar.jpg',
        bio: 'Coding in Cosmic',
        isOnline: true,
        createdAt: now,
        updatedAt: now,
        authProvider: 'password',
      );

      expect(user.uid, 'user_123');
      expect(user.name, 'Rahul Sharma');
      expect(user.displayName, 'Rahul Sharma');
      expect(user.photoURL, 'https://storage.googleapis.com/avatar.jpg');
      expect(user.profilePhoto, 'https://storage.googleapis.com/avatar.jpg');
      expect(user.authProvider, 'password');

      final map = user.toMap();
      expect(map['uid'], 'user_123');
      expect(map['name'], 'Rahul Sharma');
      expect(map['displayName'], 'Rahul Sharma');
      expect(map['photoURL'], 'https://storage.googleapis.com/avatar.jpg');
      expect(map['profilePhoto'], 'https://storage.googleapis.com/avatar.jpg');
      expect(map['authProvider'], 'password');
    });

    test('Safely parses map with missing or alternate fields (auto-recovery fallback)', () {
      final map = <String, dynamic>{
        'uid': 'user_456',
        'name': 'Priya Singh',
        'email': 'priya@example.com',
        // username, displayName, photoURL missing
      };

      final user = UserModel.fromMap(map);

      expect(user.uid, 'user_456');
      expect(user.name, 'Priya Singh');
      expect(user.displayName, 'Priya Singh');
      expect(user.username, 'priya');
      expect(user.email, 'priya@example.com');
      expect(user.phone, '');
      expect(user.photoURL, '');
      expect(user.authProvider, 'password');
    });

    test('Parses Timestamp lastSeen and createdAt correctly', () {
      final testTime = DateTime(2026, 11, 4, 10, 30);
      final map = <String, dynamic>{
        'uid': 'user_789',
        'displayName': 'Amit Patel',
        'email': 'amit@example.com',
        'createdAt': Timestamp.fromDate(testTime),
        'lastSeen': Timestamp.fromDate(testTime),
        'authProvider': 'phone',
        'phone': '+919988776655',
      };

      final user = UserModel.fromMap(map);

      expect(user.authProvider, 'phone');
      expect(user.phone, '+919988776655');
      expect(user.createdAt, testTime);
      expect(user.lastSeen, testTime);
    });
  });
}

