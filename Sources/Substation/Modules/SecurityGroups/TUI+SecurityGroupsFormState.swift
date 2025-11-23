// Sources/Substation/Modules/SecurityGroups/TUI+SecurityGroupsFormState.swift
import Foundation

/// Container for Security Groups module form state variables
///
/// This struct encapsulates all form state for the Security Groups module,
/// reducing the number of properties stored directly in the TUI class.
struct SecurityGroupsFormState {
    // MARK: - Security Group Creation

    /// Form for creating new security groups
    var createForm = SecurityGroupCreateForm()

    /// State for security group create form
    var createFormState: FormBuilderState = FormBuilderState(fields: [])

    // MARK: - Security Group Management

    /// Form for managing security groups
    var managementForm = SecurityGroupManagementForm()

    /// Form for managing security group rules
    var ruleManagementForm: SecurityGroupRuleManagementForm?
}

// MARK: - TUI Extension for Security Groups Form State Accessors

/// TUI extension providing computed property accessors for Security Groups module form state
///
/// These accessors retrieve form state from the SecurityGroupsModule via ModuleRegistry,
/// maintaining backward compatibility with existing code.
@MainActor
extension TUI {
    /// Helper to get Security Groups module from registry
    private var securityGroupsModule: SecurityGroupsModule? {
        return ModuleRegistry.shared.module(for: "securitygroups") as? SecurityGroupsModule
    }

    // MARK: - Security Group Creation Accessors

    /// Form for creating new security groups
    internal var securityGroupCreateForm: SecurityGroupCreateForm {
        get { return securityGroupsModule?.formState.createForm ?? SecurityGroupCreateForm() }
        set { securityGroupsModule?.formState.createForm = newValue }
    }

    /// State for security group create form
    internal var securityGroupCreateFormState: FormBuilderState {
        get { return securityGroupsModule?.formState.createFormState ?? FormBuilderState(fields: []) }
        set { securityGroupsModule?.formState.createFormState = newValue }
    }

    // MARK: - Security Group Management Accessors

    /// Form for managing security groups
    internal var securityGroupForm: SecurityGroupManagementForm {
        get { return securityGroupsModule?.formState.managementForm ?? SecurityGroupManagementForm() }
        set { securityGroupsModule?.formState.managementForm = newValue }
    }

    /// Form for managing security group rules
    internal var securityGroupRuleManagementForm: SecurityGroupRuleManagementForm? {
        get { return securityGroupsModule?.formState.ruleManagementForm }
        set { securityGroupsModule?.formState.ruleManagementForm = newValue }
    }
}
