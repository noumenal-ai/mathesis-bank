// The client entry. Every generated page renders its record fully without this
// file: the mounts add behaviour, never content.

import "../tailwind.css";
import { mountClipboard, mountDag, mountExpanders, mountKeyboard, mountMenus } from "./record";
import { mountCollection } from "./collection";
import { mountPostsFilter } from "./posts";
import { mountTableSort } from "./table";

function boot(): void {
  mountClipboard(document);
  mountDag(document);
  mountExpanders(document);
  mountKeyboard(document);
  mountMenus(document);
  switch (document.body.getAttribute("data-page")) {
    case "posts":
      mountPostsFilter(document);
      break;
    case "ide":
      // The editor is an island: only this page downloads it.
      void import("./ide/mount").then((m) => m.mountIde(document));
      break;
    case "collection":
      mountCollection(document);
      mountTableSort(document);
      break;
    default:
      break;
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", boot, { once: true });
} else {
  boot();
}
