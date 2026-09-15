import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';

import { Button } from '@hokulea/ember';

export class Counter extends Component {
  @tracked counter = 0;

  inc = () => {
    this.counter++;
  };

  dec = () => {
    this.counter--;
  };

  <template>
    <Button @push={{this.inc}}>+</Button>
    <Button @push={{this.dec}}>-</Button>
    <span>Counter: {{this.counter}}</span>
  </template>
}
