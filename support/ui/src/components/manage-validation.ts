import { type FunctionBasedModifier, modifier } from 'ember-modifier';

export interface NamedOptions {
  /** @internal */
  invalid: boolean;

  /** @internal */
  errorMessageId: string;

  /** @internal */
  showErrors?: boolean;
}

type ValidationElements =
  HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement | HTMLDivElement;

// eslint-disable-next-line @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-call
export const manageValidation = modifier<ValidationElements, [], NamedOptions>(
  (element: ValidationElements, _: [], { showErrors, invalid, errorMessageId }: NamedOptions) => {
    if (showErrors !== false) {
      element.ariaInvalid = invalid ? 'true' : 'false';

      if (invalid) {
        element.setAttribute('aria-errormessage', errorMessageId);
      } else {
        element.removeAttribute('aria-errormessage');
      }

      if (element.parentElement && 'inputBuilder' in element.parentElement.dataset) {
        element.parentElement.dataset.invalid = invalid ? 'true' : 'false';
      }
    }

    return;
  }
) as FunctionBasedModifier<{
  Args: {
    Positional: [];
    Named: NamedOptions;
  };
  Element: ValidationElements;
}>;
