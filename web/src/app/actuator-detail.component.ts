import { Component, OnInit, OnDestroy } from '@angular/core';
import { ActivatedRoute, Params } from '@angular/router';
import { Location } from '@angular/common';
import { MatSnackBar } from '@angular/material';
import {MatSliderModule} from '@angular/material/slider';

import { Observable, Subscription } from 'rxjs';
import { Actuator } from './actuator';
import { ActuatorService } from './actuator.service';
import {
  IMqttMessage,
  MqttModule,
  MqttService,
  IMqttServiceOptions
} from 'ngx-mqtt';

@Component({
  selector: 'app-actuator-detail',
  templateUrl: './actuator-detail.component.html',
  styleUrls: [ './actuator-detail.component.css' ]
})

export class ActuatorDetailComponent implements OnInit, OnDestroy {
  actuator: Actuator;
  private subscription: Subscription;
  private message: string;

  constructor(
    private actuatorService: ActuatorService,
    private route: ActivatedRoute,
    private location: Location,
    private _mqttService: MqttService,
    public snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.route.params
      .subscribe((params: Params) => this.actuatorService.getActuator(+params['device_id'], +params['id'])
                 .subscribe(actuator => {
                   this.subscribe_actuator(actuator.device_id, actuator.id);
                   this.actuator = actuator;
                 }));
  }

  subscribe_actuator(device_id: number, actuator_id: number): void {
    this.subscription = this._mqttService.observe(`JohnDoEx/${device_id}/actuator/${actuator_id}`).subscribe((message: IMqttMessage) => {
      this.actuatorService.getActuator(device_id, actuator_id)
        .subscribe( actuator => this.actuator = actuator);
    });
  }

  ngOnDestroy(): void {
    this.subscription.unsubscribe();
  }

  openSnackBar(message: string, action: string) {
    this.snackBar.open(message, action, { duration: 2000 });
  }

  save(): void {
    this.actuatorService.update(this.actuator)
      .subscribe(() =>  this.openSnackBar('Actuator saved', ''));
  }

  destroy(): void {
    this.actuatorService.delete(this.actuator)
      .subscribe(() => {
        this.openSnackBar('Actuator destroyed', '');
        this.goBack();
      });
  }

  goBack(): void {
    this.location.back();
  }
}
