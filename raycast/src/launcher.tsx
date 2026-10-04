import { LaunchProps } from "@raycast/api";
import Browser from "./browser";
export default function Launcher(props: LaunchProps) {
  return <Browser fallbackText={props.fallbackText} />;
}
