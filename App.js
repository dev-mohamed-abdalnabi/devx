import React from "react";
import { StatusBar } from "expo-status-bar";
import RootNavigation from "./src/navigation";

export default function App() {
  return (
    <>
      <StatusBar style="light" />
      <RootNavigation />
    </>
  );
}
