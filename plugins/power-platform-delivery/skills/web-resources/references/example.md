# Worked example: a data-driven form handler

The capability is "show or hide controls according to rules". It is named for that capability, and the rules are JSON supplied when the handler is registered. The first requirement (for example, hide the notes when a Case is closed) is one rule. The next similar requirement is another registration, not another script.

The code was formatted with the toolchain's Prettier configuration and run through its lint, build, Jest tests and bundle contract test with no errors. Adapt the shape, not the behaviour.

## Order of work

1. Test the simplest case, then a second configuration, then invalid input. Run each and confirm it fails for the right reason.
2. Write the smallest script that passes each test.
3. Run `npm test`. The build discovers the script, and the contract test checks its bundle.

## 1. Test

`tests/case.form.test.ts`. Mocks are built explicitly for the calls the script makes. The third test proves nothing is hard-coded: keep one in every data-driven script.

```ts
import { applyVisibilityRules } from '../src/case.form';

type Control = { setVisible: jest.Mock };

function buildContext(statusValue: unknown) {
  const reference: Control = { setVisible: jest.fn() };
  const notes: Control = { setVisible: jest.fn() };
  const controls: Record<string, Control> = { abc_reference: reference, abc_notes: notes };
  const formContext = {
    getAttribute: jest.fn((name: string) =>
      name === 'abc_status' ? { getValue: () => statusValue } : null
    ),
    getControl: jest.fn((name: string) => controls[name] ?? null),
  };
  const executionContext = {
    getFormContext: () => formContext,
  } as unknown as Xrm.Events.EventContext;

  return { reference, notes, executionContext };
}

const rules = JSON.stringify([
  { attribute: 'abc_status', equals: 'open', controls: ['abc_reference', 'abc_notes'] },
]);

describe('applyVisibilityRules', () => {
  test('shows the controls when the attribute equals the configured value', () => {
    const { reference, notes, executionContext } = buildContext('open');
    applyVisibilityRules(executionContext, rules);
    expect(reference.setVisible).toHaveBeenCalledWith(true);
    expect(notes.setVisible).toHaveBeenCalledWith(true);
  });

  test('hides the controls when it does not', () => {
    const { reference, executionContext } = buildContext('closed');
    applyVisibilityRules(executionContext, rules);
    expect(reference.setVisible).toHaveBeenCalledWith(false);
  });

  test('a different configuration drives different behaviour with no code change', () => {
    const { reference, notes, executionContext } = buildContext(2);
    applyVisibilityRules(
      executionContext,
      JSON.stringify([{ attribute: 'abc_status', equals: 2, controls: ['abc_notes'] }])
    );
    expect(notes.setVisible).toHaveBeenCalledWith(true);
    expect(reference.setVisible).not.toHaveBeenCalled();
  });

  test.each(['', 'not json', '{}', '[{}]'])('rejects invalid configuration %p', (config) => {
    const { executionContext } = buildContext('open');
    expect(() => applyVisibilityRules(executionContext, config)).toThrow();
  });

  test('throws a clear error when a configured control is missing', () => {
    const { executionContext } = buildContext('open');
    expect(() =>
      applyVisibilityRules(
        executionContext,
        JSON.stringify([{ attribute: 'abc_status', equals: 'open', controls: ['missing'] }])
      )
    ).toThrow("Required control 'missing' was not found.");
  });
});
```

## 2. Script

`src/case.form.ts`. Exported functions are the handlers. The configuration is parsed and validated in one place with a type guard, and bad configuration fails with a clear message.

```ts
export interface VisibilityRule {
  attribute: string;
  equals: string | number | boolean | null;
  controls: string[];
}

/**
 * Shows or hides controls according to rules supplied as JSON when the handler is registered,
 * for example [{"attribute":"abc_status","equals":"open","controls":["abc_reference"]}].
 * The rules are configuration, so a form needs no code change to use a different set.
 */
export function applyVisibilityRules(
  executionContext: Xrm.Events.EventContext,
  rulesJson: string
): void {
  const formContext = executionContext.getFormContext();
  for (const rule of parseRules(rulesJson)) {
    const visible = requiredAttribute(formContext, rule.attribute).getValue() === rule.equals;
    for (const controlName of rule.controls) {
      requiredControl(formContext, controlName).setVisible(visible);
    }
  }
}

function parseRules(rulesJson: string): VisibilityRule[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(rulesJson);
  } catch {
    throw new Error('The visibility rules are not valid JSON.');
  }

  if (!Array.isArray(parsed) || parsed.length === 0) {
    throw new Error('The visibility rules must be a non-empty array.');
  }

  return parsed.map((item: unknown) => {
    if (!isVisibilityRule(item)) {
      throw new Error('Each visibility rule needs an attribute, an equals value and controls.');
    }

    return item;
  });
}

function isVisibilityRule(item: unknown): item is VisibilityRule {
  if (typeof item !== 'object' || item === null) {
    return false;
  }

  const rule = item as Record<string, unknown>;
  return (
    typeof rule.attribute === 'string' &&
    'equals' in rule &&
    Array.isArray(rule.controls) &&
    rule.controls.length > 0
  );
}

function requiredAttribute(formContext: Xrm.FormContext, name: string): Xrm.Attributes.Attribute {
  const attribute = formContext.getAttribute(name);
  if (!attribute) {
    throw new Error(`Required attribute '${name}' was not found.`);
  }

  return attribute;
}

function requiredControl(formContext: Xrm.FormContext, name: string): Xrm.Controls.StandardControl {
  const control = formContext.getControl<Xrm.Controls.StandardControl>(name);
  if (!control) {
    throw new Error(`Required control '${name}' was not found.`);
  }

  return control;
}
```

The bundle is `dist/case.form.js` and exposes `Case.Form`. The solution calls `Case.Form.applyVisibilityRules` with "Pass execution context as first parameter" ticked and the rules JSON as the next parameter.

## Other shapes

- **Ribbon button that calls an action.** Export a function taking `primaryControl: Xrm.FormContext`. Wrap the work in `try`, `catch` and `finally`, report errors with `Xrm.Navigation.openErrorDialog`, close the progress indicator in `finally`, and take the action name or any GUID as a parameter. In tests, install a global `Xrm` containing only the calls the handler makes, with `mockResolvedValue` and `mockRejectedValue` for the async ones.
- **Module-level state.** In `beforeEach`, call `jest.resetModules()` and `require` the script afresh. This is the one accepted use of a narrow `eslint-disable-next-line @typescript-eslint/no-require-imports` with approval. Prefer removing the state.
