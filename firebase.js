// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyAmvTJ10X1xfIpIMP-38IEpRaN8dTAfliY",
  authDomain: "radar-admin-15f47.firebaseapp.com",
  projectId: "radar-admin-15f47",
  storageBucket: "radar-admin-15f47.firebasestorage.app",
  messagingSenderId: "622124734098",
  appId: "1:622124734098:web:615c3c95c330221478f84b",
  measurementId: "G-5C2RHG914L"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);

