import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, Params } from '@angular/router';
import { Location } from '@angular/common';
import { MatSnackBar } from '@angular/material';

import { Metric } from './metric';
import { Measure } from './measure';
import { MetricService } from './metric.service';
import { MeasureService } from './measure.service';
import { MeasureComponent } from './measure.component';

@Component({
  selector: 'app-metric-detail',
  templateUrl: './metric-detail.component.html',
  styleUrls: [ './metric-detail.component.css' ]
})

export class MetricDetailComponent implements OnInit {
  metric: Metric;
  measures: Measure[];
  device_id: number;
  metric_id: number;

  public data: Array<any>;

  constructor(
    private metricService: MetricService,
    private measureService: MeasureService,
    private route: ActivatedRoute,
    private location: Location,
    public snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.route.params
      .subscribe((params: Params) => this.metricService.getMetric(+params['device_id'], +params['id'])
                 .subscribe(metric => this.metric = metric));
    this.route.params
      .subscribe((params: Params) => this.measureService.getMeasures(+params['device_id'], +params['id'])
                 .subscribe(measures => this.measures = measures.reverse()));

  }

  openSnackBar(message: string, action: string) {
    this.snackBar.open(message, action, { duration: 2000 });
  }

  save(): void {
    this.metricService.update(this.metric)
      .subscribe(() => this.openSnackBar('Metric saved', ''));
  }

  destroy(): void {
    this.metricService.delete(this.metric.id, this.metric.device_id)
      .subscribe(() => {
        this.openSnackBar('Metric destroyed', '');
        this.goBack();
      });
  }

  goBack(): void {
    this.location.back();
  }
}
