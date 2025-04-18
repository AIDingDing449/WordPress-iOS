import UIKit

/// Coordinates the UI flow for creating a new site
final class SiteCreationWizard: Wizard {
    private lazy var navigation: WizardNavigation? = {
        return WizardNavigation(steps: self.steps)
    }()

    var content: UIViewController? {
        return navigation
    }

    // The sequence of steps to complete the wizard.
    let steps: [WizardStep]

    init(steps: [WizardStep]) {
        self.steps = steps
    }
}
