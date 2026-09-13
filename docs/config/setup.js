// IT Architektúra – központi kliensoldali beállítások
//
// true  = funkció bekapcsolva
// false = funkció kikapcsolva
//
// A feladatszintű ellenőrzések egyetlen kapcsolóval teljesen kikapcsolhatók.
// A szintaktikai és AI-ellenőrzés külön-külön is letiltható.

window.ITARCH_SETUP = {
  timeTracking: true,
  eventTracking: true,
  showTrackingPanel: true,

  checksEnabled: true,                 // globális kapcsoló minden ellenőrző gombhoz
  syntaxChecks: true,                  // szintaktikai ellenőrzések
  aiChecks: true,                      // AI-ellenőrzések
  showChecksInSubmissionSummary: true, // ellenőrzési összesítés a beadás előtt
  requireChecksBeforeSubmission: false,// alapból az ellenőrzés nem kötelező a beadáshoz

  allowImport: false                   // jelenleg rejtve; szerveres mentésnél elhagyható
};
