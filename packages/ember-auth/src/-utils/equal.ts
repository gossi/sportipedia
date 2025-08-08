/* eslint-disable @typescript-eslint/no-unsafe-member-access */
/* eslint-disable no-prototype-builtins */
/* eslint-disable @typescript-eslint/no-unsafe-call */
/* eslint-disable @typescript-eslint/no-explicit-any */
export default function isEqual(a: any, b: any) {
  function compare(x: any, y: any) {
    let property;

    if (Number.isNaN(x) && Number.isNaN(y) && typeof x === 'number' && typeof y === 'number') {
      return true;
    }

    if (x === y) {
      return true;
    }

    if (!(x instanceof Object && y instanceof Object)) {
      return false;
    }

    for (property in y) {
      if (y.hasOwnProperty(property) !== x.hasOwnProperty(property)) {
        return false;
      } else if (typeof y[property] !== typeof x[property]) {
        return false;
      }
    }

    for (property in x) {
      if (y.hasOwnProperty(property) !== x.hasOwnProperty(property)) {
        return false;
      } else if (typeof y[property] !== typeof x[property]) {
        return false;
      }

      switch (typeof x[property]) {
        case 'object': {
          if (!compare(x[property], y[property])) {
            return false;
          }

          break;
        }

        default: {
          if (x[property] !== y[property]) {
            return false;
          }

          break;
        }
      }
    }

    return true;
  }

  return compare(a, b);
}
