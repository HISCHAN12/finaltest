import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void> addUserToFirestore(User user, {String? statusMessage}) async {
  final CollectionReference users =
      FirebaseFirestore.instance.collection('user');

  final userData = {
    'uid': user.uid,
    'email': user.email,
    'name': user.displayName,
    'status_message':
        statusMessage ?? 'I promise to take the test honestly before GOD.',
    'created_at': FieldValue.serverTimestamp(),
  };

  await users.doc(user.uid).set(userData, SetOptions(merge: true));
}

Future<void> addGuestToFirestore(User user) async {
  final CollectionReference users =
      FirebaseFirestore.instance.collection('user');

  final userData = {
    'uid': user.uid,
    'name': '게스트',
    'status_message': 'I promise to take the test honestly before GOD.',
    'created_at': FieldValue.serverTimestamp(),
    'is_guest': true,
  };

  await users.doc(user.uid).set(userData, SetOptions(merge: true));
}

Future<UserCredential> signInWithGoogle(BuildContext context) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }

    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER', message: 'Sign in aborted by user');
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final user = userCredential.user!;

    await addUserToFirestore(user);

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }

    return userCredential;
  } catch (e) {
    print('Google 로그인 오류: $e');
    rethrow;
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/diamond.png'),
              const SizedBox(height: 16.0),
              const Text('SHRINE'),
              const SizedBox(height: 50),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () async {
                  try {
                    await signInWithGoogle(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('로그인 실패: $e')),
                    );
                  }
                },
                child: const Text('Google 로그인'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () async {
                  try {
                    final userCredential =
                        await FirebaseAuth.instance.signInAnonymously();
                    final user = userCredential.user!;
                    await addGuestToFirestore(user);

                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/');
                    }
                  } on FirebaseAuthException catch (e) {
                    // FirebaseAuthException 코드와 메시지를 모두 출력
                    String message = '알 수 없는 오류가 발생했습니다. (코드: ${e.code})';
                    if (e.code == 'operation-not-allowed') {
                      message = '익명 로그인이 비활성화되어 있습니다.';
                    } else if (e.code == 'network-request-failed') {
                      message = '네트워크 연결을 확인하세요.';
                    } else if (e.code == 'internal-error') {
                      message = '내부 오류가 발생했습니다. 다시 시도해주세요.';
                    }
                    print("FirebaseAuthException: ${e.code} - ${e.message}");
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    }
                  } catch (e) {
                    // 기타 예상치 못한 에러 출력
                    print("Exception: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('알 수 없는 오류가 발생했습니다: $e')),
                    );
                  }
                },
                child: const Text('게스트 로그인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
